import json
from urllib import error as urllib_error
from urllib import parse as urllib_parse
from urllib import request as urllib_request

from django.db import transaction
from django.db.models import Avg, Q
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from rides.models import Complaint, Review, Ride, RideBooking, Seat
from rides.serializers import (
    BookingCreateSerializer,
    BookingSerializer,
    ComplaintCreateSerializer,
    ComplaintSerializer,
    ReviewCreateSerializer,
    ReviewSerializer,
    RideCreateSerializer,
    RideDetailSerializer,
    RideListSerializer,
)
from users.models import DriverProfile
from users.permissions import IsDriver, IsPassenger, IsVerifiedUser


# ---------------------------------------------------------------------------
# Reverse Geocode Proxy (unchanged)
# ---------------------------------------------------------------------------

class ReverseGeocodeView(APIView):
    """
    GET /api/maps/reverse/?lat=<float>&lng=<float>

    Server-side proxy to Nominatim so Flutter Web avoids browser CORS limits.
    Returns a shortened address string.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        lat = request.query_params.get("lat")
        lng = request.query_params.get("lng")

        if not lat or not lng:
            return Response(
                {"detail": "Both 'lat' and 'lng' are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            lat_f = float(lat)
            lng_f = float(lng)
        except (TypeError, ValueError):
            return Response(
                {"detail": "Invalid coordinates."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        query = urllib_parse.urlencode(
            {
                "lat": f"{lat_f:.7f}",
                "lon": f"{lng_f:.7f}",
                "format": "json",
                "accept-language": "en",
            }
        )
        url = f"https://nominatim.openstreetmap.org/reverse?{query}"
        req = urllib_request.Request(
            url,
            headers={"User-Agent": "RideUz/1.0 (contact@rideuz.uz)"},
        )

        try:
            with urllib_request.urlopen(req, timeout=8) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
        except (urllib_error.URLError, TimeoutError, json.JSONDecodeError):
            return Response(
                {"address": f"{lat_f:.5f}, {lng_f:.5f}"},
                status=status.HTTP_200_OK,
            )

        display = str(payload.get("display_name") or "").strip()
        if display:
            address = ",".join(display.split(",")[:3]).strip()
            return Response({"address": address}, status=status.HTTP_200_OK)

        return Response(
            {"address": f"{lat_f:.5f}, {lng_f:.5f}"},
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# Rides
# ---------------------------------------------------------------------------

class RideViewSet(viewsets.ModelViewSet):
    """
    Core ride endpoint for the carpooling model.

    Router-generated routes:
      GET  /api/rides/          — list/search rides
      POST /api/rides/          — Driver creates a ride
      GET  /api/rides/{id}/     — retrieve a single ride (full detail + seats)

    Custom @action routes:
      POST /api/rides/{id}/start/    — Driver starts   (PUBLISHED → ONGOING)
      POST /api/rides/{id}/complete/ — Driver completes (ONGOING   → COMPLETED)
      POST /api/rides/{id}/cancel/   — Driver cancels   (PUBLISHED → CANCELED)
      POST /api/rides/{id}/book/     — Passenger books a seat

    PUT / PATCH / DELETE are disabled — mutations go through actions.
    """

    http_method_names = ["get", "post", "head", "options"]

    # ------------------------------------------------------------------
    # DRF hooks
    # ------------------------------------------------------------------

    def get_permissions(self):
        if self.action == "create":
            return [IsDriver()]
        if self.action in ("start", "complete", "cancel"):
            return [IsDriver()]
        if self.action == "book":
            return [IsPassenger()]
        return [IsVerifiedUser()]

    def get_serializer_class(self):
        if self.action == "create":
            return RideCreateSerializer
        if self.action == "list":
            return RideListSerializer
        return RideDetailSerializer

    def get_queryset(self):
        """
        - Passengers see all PUBLISHED rides (for searching)
          plus rides they have bookings on.
        - Drivers see their own rides (all statuses).
        - Search/filter is handled via query params.
        """
        user = self.request.user
        qs = Ride.objects.select_related("driver", "driver__driver_profile")

        if user.role == "DRIVER":
            qs = qs.filter(driver=user)
        elif user.role == "PASSENGER":
            booked_ride_ids = RideBooking.objects.filter(
                passenger=user, status=RideBooking.Status.CONFIRMED
            ).values_list("ride_id", flat=True)
            qs = qs.filter(
                Q(status=Ride.Status.PUBLISHED) | Q(pk__in=booked_ride_ids)
            ).distinct()
        else:
            return Ride.objects.none()

        # --- Search / filter query params ---
        origin = self.request.query_params.get("origin")
        destination = self.request.query_params.get("destination")
        date = self.request.query_params.get("date")          # YYYY-MM-DD
        min_seats = self.request.query_params.get("min_seats")  # integer
        max_price = self.request.query_params.get("max_price")  # decimal
        sort = self.request.query_params.get("sort")            # price, time, -price, -time

        if origin:
            qs = qs.filter(origin__icontains=origin)
        if destination:
            qs = qs.filter(destination__icontains=destination)
        if date:
            qs = qs.filter(departure_time__date=date)
        if min_seats:
            try:
                qs = qs.filter(available_seats__gte=int(min_seats))
            except ValueError:
                pass
        if max_price:
            try:
                qs = qs.filter(price_per_seat__lte=float(max_price))
            except ValueError:
                pass

        # Sorting
        if sort == "price":
            qs = qs.order_by("price_per_seat")
        elif sort == "-price":
            qs = qs.order_by("-price_per_seat")
        elif sort == "time":
            qs = qs.order_by("departure_time")
        elif sort == "-time":
            qs = qs.order_by("-departure_time")

        return qs

    def perform_create(self, serializer):
        """Inject the authenticated driver."""
        serializer.save(driver=self.request.user)

    # ------------------------------------------------------------------
    # State-machine @actions (Driver)
    # ------------------------------------------------------------------

    @action(detail=True, methods=["post"], url_path="start")
    def start(self, request, pk=None):
        """PUBLISHED → ONGOING. Only the ride's driver."""
        ride = self.get_object()

        if ride.driver_id != request.user.pk:
            return Response(
                {"detail": "You are not the driver of this ride."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if ride.status != Ride.Status.PUBLISHED:
            return Response(
                {"detail": f"Cannot start a ride in '{ride.status}' state."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ride.status = Ride.Status.ONGOING
        ride.started_at = timezone.now()
        ride.save(update_fields=["status", "started_at"])

        return Response(RideDetailSerializer(ride).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="complete")
    def complete(self, request, pk=None):
        """ONGOING → COMPLETED. Only the ride's driver."""
        ride = self.get_object()

        if ride.driver_id != request.user.pk:
            return Response(
                {"detail": "You are not the driver of this ride."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if ride.status != Ride.Status.ONGOING:
            return Response(
                {"detail": f"Cannot complete a ride in '{ride.status}' state."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ride.status = Ride.Status.COMPLETED
        ride.completed_at = timezone.now()
        ride.save(update_fields=["status", "completed_at"])

        return Response(RideDetailSerializer(ride).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="cancel")
    def cancel(self, request, pk=None):
        """PUBLISHED → CANCELED. Only the ride's driver."""
        ride = self.get_object()

        if ride.driver_id != request.user.pk:
            return Response(
                {"detail": "You are not the driver of this ride."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if ride.status != Ride.Status.PUBLISHED:
            return Response(
                {"detail": f"Cannot cancel a ride in '{ride.status}' state."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ride.status = Ride.Status.CANCELED
        ride.canceled_at = timezone.now()
        ride.save(update_fields=["status", "canceled_at"])

        # Cancel all confirmed bookings on this ride
        ride.bookings.filter(status=RideBooking.Status.CONFIRMED).update(
            status=RideBooking.Status.CANCELED, canceled_at=timezone.now()
        )

        return Response(RideDetailSerializer(ride).data, status=status.HTTP_200_OK)

    # ------------------------------------------------------------------
    # Booking @action (Passenger)
    # ------------------------------------------------------------------

    @action(detail=True, methods=["post"], url_path="book")
    def book(self, request, pk=None):
        """
        Passenger books a specific seat.
        Auto-approved: the seat is immediately reserved.
        Uses select_for_update to prevent race conditions.
        """
        ride = self.get_object()

        if ride.status != Ride.Status.PUBLISHED:
            return Response(
                {"detail": "Bookings are only allowed on PUBLISHED rides."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = BookingCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        seat_id = serializer.validated_data["seat_id"]
        payment_method = serializer.validated_data.get("payment_method", "CASH")

        # Validate payment method against what the driver accepts
        if ride.payment_method != Ride.PaymentMethod.BOTH:
            if payment_method != ride.payment_method:
                return Response(
                    {"detail": f"This ride only accepts {ride.payment_method} payments."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        with transaction.atomic():
            try:
                seat = Seat.objects.select_for_update().get(
                    pk=seat_id, ride=ride
                )
            except Seat.DoesNotExist:
                return Response(
                    {"detail": "Seat not found on this ride."},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if not seat.is_available:
                return Response(
                    {"detail": "This seat is already booked."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Check if passenger already has a booking on this ride
            if RideBooking.objects.filter(
                ride=ride, passenger=request.user, status=RideBooking.Status.CONFIRMED
            ).exists():
                return Response(
                    {"detail": "You already have a confirmed booking on this ride."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            seat.is_available = False
            seat.save(update_fields=["is_available"])

            booking = RideBooking.objects.create(
                ride=ride,
                passenger=request.user,
                seat=seat,
                payment_method=payment_method,
                status=RideBooking.Status.CONFIRMED,
            )

            ride.available_seats -= 1
            ride.save(update_fields=["available_seats"])

        return Response(BookingSerializer(booking).data, status=status.HTTP_201_CREATED)


# ---------------------------------------------------------------------------
# Bookings (Passenger view)
# ---------------------------------------------------------------------------

class BookingViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    """
    GET  /api/bookings/        — list caller's own bookings
    GET  /api/bookings/{id}/   — retrieve a specific booking
    POST /api/bookings/{id}/cancel/ — cancel a booking
    """
    permission_classes = [IsVerifiedUser]
    serializer_class = BookingSerializer

    def get_queryset(self):
        return RideBooking.objects.filter(
            passenger=self.request.user
        ).select_related("ride", "seat", "passenger")

    @action(detail=True, methods=["post"], url_path="cancel")
    def cancel_booking(self, request, pk=None):
        """Cancel a confirmed booking. Frees up the seat."""
        booking = self.get_object()

        if booking.passenger_id != request.user.pk:
            return Response(
                {"detail": "You can only cancel your own bookings."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if booking.status != RideBooking.Status.CONFIRMED:
            return Response(
                {"detail": f"Cannot cancel a booking in '{booking.status}' state."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if booking.ride.status not in (Ride.Status.PUBLISHED,):
            return Response(
                {"detail": "Cannot cancel a booking after the ride has started."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            booking.status = RideBooking.Status.CANCELED
            booking.canceled_at = timezone.now()
            booking.save(update_fields=["status", "canceled_at"])

            booking.seat.is_available = True
            booking.seat.save(update_fields=["is_available"])

            booking.ride.available_seats += 1
            booking.ride.save(update_fields=["available_seats"])

        return Response(BookingSerializer(booking).data, status=status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# Reviews
# ---------------------------------------------------------------------------

class ReviewViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    """
    POST /api/reviews/        — submit a review (after COMPLETED ride)
    GET  /api/reviews/        — list reviews received by the caller
    GET  /api/reviews/{id}/   — retrieve a specific review
    """
    permission_classes = [IsVerifiedUser]

    def get_serializer_class(self):
        if self.action == "create":
            return ReviewCreateSerializer
        return ReviewSerializer

    def get_queryset(self):
        return Review.objects.filter(
            Q(reviewer=self.request.user) | Q(reviewee=self.request.user)
        ).select_related("reviewer", "reviewee", "ride")

    def create(self, request, *args, **kwargs):
        serializer = ReviewCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        ride = serializer.validated_data["ride"]
        reviewee = serializer.validated_data["reviewee"]

        # Ride must be completed
        if ride.status != Ride.Status.COMPLETED:
            raise ValidationError({"ride": "Reviews can only be submitted for completed rides."})

        # Reviewer must be a participant
        user = request.user
        is_driver = ride.driver_id == user.pk
        is_passenger = RideBooking.objects.filter(
            ride=ride, passenger=user, status=RideBooking.Status.CONFIRMED
        ).exists()

        if not is_driver and not is_passenger:
            raise PermissionDenied("You are not a participant of this ride.")

        # Reviewer cannot review themselves
        if reviewee.pk == user.pk:
            raise ValidationError({"reviewee": "You cannot review yourself."})

        # Reviewee must also be a participant
        reviewee_is_driver = ride.driver_id == reviewee.pk
        reviewee_is_passenger = RideBooking.objects.filter(
            ride=ride, passenger=reviewee, status=RideBooking.Status.CONFIRMED
        ).exists()

        if not reviewee_is_driver and not reviewee_is_passenger:
            raise ValidationError({"reviewee": "The reviewee is not a participant of this ride."})

        # One review per ride per reviewer
        if Review.objects.filter(ride=ride, reviewer=user).exists():
            raise ValidationError({"ride": "You have already reviewed this ride."})

        instance = serializer.save(reviewer=user)
        return Response(
            ReviewSerializer(instance).data,
            status=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# Complaints
# ---------------------------------------------------------------------------

class ComplaintViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    """
    GET  /api/complaints/        — list caller's own complaints
    POST /api/complaints/        — file a new complaint
    GET  /api/complaints/{id}/   — retrieve a specific complaint
    """
    permission_classes = [IsVerifiedUser]

    def get_serializer_class(self):
        if self.action == "create":
            return ComplaintCreateSerializer
        return ComplaintSerializer

    def get_queryset(self):
        return Complaint.objects.filter(filed_by=self.request.user)

    def create(self, request, *args, **kwargs):
        ride_id = request.data.get("ride_id")
        if not ride_id:
            raise ValidationError({"ride_id": "This field is required."})

        try:
            ride = Ride.objects.get(pk=ride_id)
        except Ride.DoesNotExist:
            raise ValidationError({"ride_id": f"Ride with id {ride_id} does not exist."})

        user = request.user
        is_driver = ride.driver_id == user.pk
        is_passenger = RideBooking.objects.filter(
            ride=ride, passenger=user, status=RideBooking.Status.CONFIRMED
        ).exists()

        if not is_driver and not is_passenger:
            raise PermissionDenied("You are not a participant of this ride.")

        serializer = ComplaintCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        instance = serializer.save(ride=ride, filed_by=user)

        return Response(
            ComplaintSerializer(instance).data,
            status=status.HTTP_201_CREATED,
        )
