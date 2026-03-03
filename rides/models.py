from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class Ride(models.Model):
    """
    A scheduled trip published by a Driver.
    Passengers search for these rides and book individual seats.
    """

    class Status(models.TextChoices):
        PUBLISHED = "PUBLISHED", "Published"
        ONGOING   = "ONGOING",   "Ongoing"
        COMPLETED = "COMPLETED", "Completed"
        CANCELED  = "CANCELED",  "Canceled"

    class PaymentMethod(models.TextChoices):
        CASH = "CASH", "Cash"
        CARD = "CARD", "Card"
        BOTH = "BOTH", "Both"

    # --- Owner (Driver) ---
    driver = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="rides_as_driver",
        limit_choices_to={"role": "DRIVER"},
    )

    # --- Route ---
    origin      = models.CharField(max_length=255)
    destination = models.CharField(max_length=255)

    origin_lat      = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    origin_lng      = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    destination_lat = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    destination_lng = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)

    # --- Schedule ---
    departure_time = models.DateTimeField()

    # --- Pricing & capacity ---
    price_per_seat   = models.DecimalField(max_digits=10, decimal_places=0)
    total_seats      = models.PositiveIntegerField()
    available_seats  = models.PositiveIntegerField()
    payment_method   = models.CharField(
        max_length=10,
        choices=PaymentMethod.choices,
        default=PaymentMethod.BOTH,
    )

    # --- Description / notes ---
    description = models.TextField(blank=True, default="")

    # --- State machine ---
    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.PUBLISHED,
    )

    # --- Timestamps ---
    created_at   = models.DateTimeField(auto_now_add=True)
    started_at   = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    canceled_at  = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "rides"
        verbose_name = "Ride"
        verbose_name_plural = "Rides"
        ordering = ["-departure_time"]

    def __str__(self):
        return f"Ride #{self.pk} | {self.origin} → {self.destination} [{self.status}]"


class Seat(models.Model):
    """
    Represents a physical seat in the car for a specific ride.
    The driver configures available seats when publishing a ride.
    """

    class Position(models.TextChoices):
        FRONT_RIGHT  = "FRONT_RIGHT",  "Front Right"
        BACK_LEFT    = "BACK_LEFT",    "Back Left"
        BACK_MIDDLE  = "BACK_MIDDLE",  "Back Middle"
        BACK_RIGHT   = "BACK_RIGHT",   "Back Right"

    ride = models.ForeignKey(
        Ride,
        on_delete=models.CASCADE,
        related_name="seats",
    )
    position     = models.CharField(max_length=20, choices=Position.choices)
    is_available = models.BooleanField(default=True)

    class Meta:
        db_table = "seats"
        verbose_name = "Seat"
        verbose_name_plural = "Seats"
        unique_together = [("ride", "position")]

    def __str__(self):
        status = "Free" if self.is_available else "Booked"
        return f"Seat {self.position} on Ride #{self.ride_id} ({status})"


class RideBooking(models.Model):
    """
    A passenger booking for a specific seat on a ride.
    Auto-approved: the seat is immediately reserved once booked.
    """

    class PaymentMethod(models.TextChoices):
        CASH = "CASH", "Cash"
        CARD = "CARD", "Card"

    class Status(models.TextChoices):
        CONFIRMED = "CONFIRMED", "Confirmed"
        CANCELED  = "CANCELED",  "Canceled"

    ride = models.ForeignKey(
        Ride,
        on_delete=models.CASCADE,
        related_name="bookings",
    )
    passenger = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="bookings",
    )
    seat = models.OneToOneField(
        Seat,
        on_delete=models.CASCADE,
        related_name="booking",
    )
    payment_method = models.CharField(
        max_length=10,
        choices=PaymentMethod.choices,
        default=PaymentMethod.CASH,
    )
    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.CONFIRMED,
    )
    booked_at   = models.DateTimeField(auto_now_add=True)
    canceled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "ride_bookings"
        verbose_name = "Ride Booking"
        verbose_name_plural = "Ride Bookings"
        ordering = ["-booked_at"]

    def __str__(self):
        return f"Booking #{self.pk} | {self.passenger} → Ride #{self.ride_id} [{self.status}]"


class Review(models.Model):
    """
    A review/rating left after a ride is COMPLETED.
    Passengers rate the driver; drivers can rate passengers.
    """

    ride = models.ForeignKey(
        Ride,
        on_delete=models.CASCADE,
        related_name="reviews",
    )
    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reviews_given",
    )
    reviewee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reviews_received",
    )
    rating  = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
    )
    comment    = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "reviews"
        verbose_name = "Review"
        verbose_name_plural = "Reviews"
        ordering = ["-created_at"]
        unique_together = [("ride", "reviewer")]

    def __str__(self):
        return f"Review by {self.reviewer} → {self.reviewee} ({self.rating}★)"


class Complaint(models.Model):
    """A complaint filed by any user against a specific ride."""

    ride = models.ForeignKey(
        Ride,
        on_delete=models.CASCADE,
        related_name="complaints",
    )
    filed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="complaints_filed",
    )
    description = models.TextField()
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "complaints"
        verbose_name = "Complaint"
        verbose_name_plural = "Complaints"
        ordering = ["-created_at"]

    def __str__(self):
        return f"Complaint #{self.pk} by {self.filed_by} on Ride #{self.ride_id}"
