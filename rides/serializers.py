from django.db import models
from rest_framework import serializers

from rides.models import Complaint, Review, Ride, RideBooking, Seat
from users.serializers import DriverPublicSerializer


# ---------------------------------------------------------------------------
# Seat
# ---------------------------------------------------------------------------

class SeatSerializer(serializers.ModelSerializer):
    """Read-only representation of a single seat including booking info."""

    booked_by_phone = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model  = Seat
        fields = ["id", "position", "is_available", "booked_by_phone"]
        read_only_fields = fields

    def get_booked_by_phone(self, obj):
        try:
            return obj.booking.passenger.phone_number
        except (RideBooking.DoesNotExist, AttributeError):
            return None


# ---------------------------------------------------------------------------
# Ride
# ---------------------------------------------------------------------------

class RideCreateSerializer(serializers.ModelSerializer):
    """
    Driver publishes a new ride.
    Writable fields: origin, destination, coordinates, departure_time,
                     price_per_seat, payment_method, description, seats.
    `seats` is a list of seat position strings (e.g. ["FRONT_RIGHT","BACK_LEFT"]).
    """

    seats = serializers.ListField(
        child=serializers.ChoiceField(choices=Seat.Position.choices),
        write_only=True,
        help_text="List of seat position labels to offer, e.g. ['FRONT_RIGHT','BACK_LEFT']",
    )

    class Meta:
        model  = Ride
        fields = [
            "id",
            "origin",
            "destination",
            "origin_lat",
            "origin_lng",
            "destination_lat",
            "destination_lng",
            "departure_time",
            "price_per_seat",
            "payment_method",
            "description",
            "seats",
            "status",
            "created_at",
        ]
        read_only_fields = ["id", "status", "created_at"]

    def validate_seats(self, value):
        if not value:
            raise serializers.ValidationError("At least one seat must be offered.")
        if len(value) != len(set(value)):
            raise serializers.ValidationError("Duplicate seat positions are not allowed.")
        return value

    def create(self, validated_data):
        seat_positions = validated_data.pop("seats")
        validated_data["total_seats"] = len(seat_positions)
        validated_data["available_seats"] = len(seat_positions)
        ride = Ride.objects.create(**validated_data)
        Seat.objects.bulk_create([
            Seat(ride=ride, position=pos) for pos in seat_positions
        ])
        return ride


class RideListSerializer(serializers.ModelSerializer):
    """
    Compact representation for search result lists.
    Includes driver info, route, time, price, and remaining seats.
    """

    driver = DriverPublicSerializer(read_only=True)
    booked_seats = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model  = Ride
        fields = [
            "id",
            "driver",
            "origin",
            "destination",
            "departure_time",
            "price_per_seat",
            "payment_method",
            "total_seats",
            "available_seats",
            "booked_seats",
            "status",
            "created_at",
        ]
        read_only_fields = fields

    def get_booked_seats(self, obj):
        return obj.total_seats - obj.available_seats


class RideDetailSerializer(serializers.ModelSerializer):
    """
    Full read representation of a ride including coordinates, all seats,
    and driver profile.
    """

    driver = DriverPublicSerializer(read_only=True)
    seats  = SeatSerializer(many=True, read_only=True)
    booked_seats = serializers.SerializerMethodField(read_only=True)
    driver_rating = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model  = Ride
        fields = [
            "id",
            "driver",
            "driver_rating",
            "origin",
            "destination",
            "origin_lat",
            "origin_lng",
            "destination_lat",
            "destination_lng",
            "departure_time",
            "price_per_seat",
            "payment_method",
            "description",
            "total_seats",
            "available_seats",
            "booked_seats",
            "seats",
            "status",
            "created_at",
            "started_at",
            "completed_at",
            "canceled_at",
        ]
        read_only_fields = fields

    def get_booked_seats(self, obj):
        return obj.total_seats - obj.available_seats

    def get_driver_rating(self, obj):
        avg = obj.driver.reviews_received.aggregate(avg=models.Avg("rating"))["avg"]
        return round(avg, 1) if avg else None


# ---------------------------------------------------------------------------
# Booking
# ---------------------------------------------------------------------------

class BookingCreateSerializer(serializers.Serializer):
    """Passenger books a specific seat on a ride."""

    seat_id = serializers.IntegerField()
    payment_method = serializers.ChoiceField(
        choices=RideBooking.PaymentMethod.choices,
        default="CASH",
    )


class BookingSerializer(serializers.ModelSerializer):
    """Read representation of a booking."""

    passenger_phone = serializers.CharField(
        source="passenger.phone_number", read_only=True,
    )
    seat_position = serializers.CharField(
        source="seat.position", read_only=True,
    )
    ride_origin = serializers.CharField(source="ride.origin", read_only=True)
    ride_destination = serializers.CharField(source="ride.destination", read_only=True)
    ride_departure_time = serializers.DateTimeField(source="ride.departure_time", read_only=True)
    ride_status = serializers.CharField(source="ride.status", read_only=True)

    class Meta:
        model  = RideBooking
        fields = [
            "id",
            "ride",
            "ride_origin",
            "ride_destination",
            "ride_departure_time",
            "ride_status",
            "passenger_phone",
            "seat_position",
            "payment_method",
            "status",
            "booked_at",
            "canceled_at",
        ]
        read_only_fields = fields


# ---------------------------------------------------------------------------
# Review
# ---------------------------------------------------------------------------

class ReviewCreateSerializer(serializers.ModelSerializer):
    """Submit a review after a COMPLETED ride."""

    class Meta:
        model  = Review
        fields = ["id", "ride", "reviewee", "rating", "comment", "created_at"]
        read_only_fields = ["id", "created_at"]

    def validate_rating(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError("Rating must be between 1 and 5.")
        return value


class ReviewSerializer(serializers.ModelSerializer):
    """Read representation of a review."""

    reviewer_phone = serializers.CharField(
        source="reviewer.phone_number", read_only=True,
    )
    reviewee_phone = serializers.CharField(
        source="reviewee.phone_number", read_only=True,
    )

    class Meta:
        model  = Review
        fields = [
            "id",
            "ride",
            "reviewer_phone",
            "reviewee_phone",
            "rating",
            "comment",
            "created_at",
        ]
        read_only_fields = fields


# ---------------------------------------------------------------------------
# Complaint
# ---------------------------------------------------------------------------

class ComplaintCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Complaint
        fields = ["id", "description", "created_at"]
        read_only_fields = ["id", "created_at"]


class ComplaintSerializer(serializers.ModelSerializer):
    filed_by_phone = serializers.CharField(
        source="filed_by.phone_number", read_only=True,
    )
    ride_id = serializers.IntegerField(source="ride.id", read_only=True)

    class Meta:
        model  = Complaint
        fields = ["id", "ride_id", "filed_by_phone", "description", "created_at"]
        read_only_fields = fields
