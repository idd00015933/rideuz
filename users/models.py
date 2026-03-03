from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    """Manager for the custom User model that uses phone_number as the unique identifier."""

    def create_user(self, phone_number, password=None, **extra_fields):
        if not phone_number:
            raise ValueError("Phone number is required.")
        user = self.model(phone_number=phone_number, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, phone_number, password, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_verified", True)
        extra_fields.setdefault("role", User.Role.PASSENGER)
        return self.create_user(phone_number, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):

    class Role(models.TextChoices):
        PASSENGER = "PASSENGER", "Passenger"
        DRIVER = "DRIVER", "Driver"

    # --- Core identification ---
    phone_number = models.CharField(max_length=20, unique=True)

    # --- OTP verification ---
    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_created_at = models.DateTimeField(blank=True, null=True)

    # --- Role & status ---
    role = models.CharField(
        max_length=10,
        choices=Role.choices,
        blank=True,
        null=True,
    )
    is_verified = models.BooleanField(default=False)
    is_blocked = models.BooleanField(default=False)

    # --- Django internals ---
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)

    objects = UserManager()

    USERNAME_FIELD = "phone_number"
    REQUIRED_FIELDS = []

    class Meta:
        db_table = "users"
        verbose_name = "User"
        verbose_name_plural = "Users"

    def __str__(self):
        return f"{self.phone_number} ({self.role or 'no role'})"

    @property
    def is_otp_valid(self):
        """OTP expires after 5 minutes."""
        if self.otp_created_at is None:
            return False
        return (timezone.now() - self.otp_created_at).total_seconds() < 300


class DriverProfile(models.Model):
    """Extended profile that exists only for users with role=DRIVER."""

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="driver_profile",
        limit_choices_to={"role": User.Role.DRIVER},
    )
    full_name = models.CharField(max_length=100, default="")
    profile_picture = models.ImageField(upload_to="profiles/drivers/", blank=True, null=True)
    car_model = models.CharField(max_length=100)
    plate_number = models.CharField(max_length=20, unique=True)
    is_online = models.BooleanField(default=False)

    class Meta:
        db_table = "driver_profiles"
        verbose_name = "Driver Profile"
        verbose_name_plural = "Driver Profiles"

    def __str__(self):
        return f"{self.user.phone_number} - {self.car_model} [{self.plate_number}]"


class PassengerProfile(models.Model):
    """Extended profile for users with role=PASSENGER."""

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="passenger_profile",
        limit_choices_to={"role": User.Role.PASSENGER},
    )
    full_name = models.CharField(max_length=100)
    profile_picture = models.ImageField(upload_to="profiles/passengers/", blank=True, null=True)

    # MVP-safe card metadata only (never store full PAN/CVV).
    card_holder_name = models.CharField(max_length=100, blank=True, default="")
    card_last4 = models.CharField(max_length=4, blank=True, default="")
    card_expiry_mm_yy = models.CharField(max_length=5, blank=True, default="")

    class Meta:
        db_table = "passenger_profiles"
        verbose_name = "Passenger Profile"
        verbose_name_plural = "Passenger Profiles"

    def __str__(self):
        return f"{self.user.phone_number} - {self.full_name}"
