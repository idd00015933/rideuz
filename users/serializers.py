from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import DriverProfile, PassengerProfile

User = get_user_model()


# ---------------------------------------------------------------------------
# Registration / Auth flow
# ---------------------------------------------------------------------------

class RegisterSerializer(serializers.ModelSerializer):
    """
    Step 1 - Phone number registration.
    Creates an unverified user. The view will generate and store a mock OTP.
    otp_code is intentionally excluded from output.

    NOTE: UniqueValidator is explicitly suppressed for phone_number.
    DRF ModelSerializer auto-injects UniqueValidator for any field marked
    unique=True on the model. Without this override, re-submitting an
    already-registered phone number raises 400 before view logic runs.
    """

    class Meta:
        model = User
        fields = ["id", "phone_number"]
        read_only_fields = ["id"]
        extra_kwargs = {
            "phone_number": {
                "validators": [],
            }
        }


class OTPVerifySerializer(serializers.Serializer):
    """
    Step 2 - OTP verification.
    """
    phone_number = serializers.CharField(max_length=20)
    otp_code = serializers.CharField(max_length=6, min_length=6)


class RoleSelectSerializer(serializers.Serializer):
    """
    Step 3 - Role selection after a verified phone number.
    """
    role = serializers.ChoiceField(choices=User.Role.choices)


# ---------------------------------------------------------------------------
# Driver profile
# ---------------------------------------------------------------------------

class DriverProfileSerializer(serializers.ModelSerializer):
    """
    Create or update a driver's profile.
    user is injected by the view from request.user.

    Requirements:
      - full_name is required
      - profile_picture is required
    """
    profile_picture = serializers.ImageField(write_only=True, required=False)
    profile_picture_url = serializers.SerializerMethodField(read_only=True)
    driver_rating = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = DriverProfile
        fields = [
            "id",
            "full_name",
            "profile_picture",
            "profile_picture_url",
            "car_model",
            "plate_number",
            "is_online",
            "driver_rating",
        ]
        read_only_fields = ["id", "driver_rating"]

    def get_profile_picture_url(self, obj):
        request = self.context.get("request")
        if not obj.profile_picture:
            return ""
        url = obj.profile_picture.url
        return request.build_absolute_uri(url) if request else url

    def get_driver_rating(self, obj):
        from django.db.models import Avg
        avg = obj.user.reviews_received.aggregate(avg=Avg("rating"))["avg"]
        if avg is None:
            return 5.0  # New drivers start with a perfect rating
        return round(avg, 1)

    def validate(self, attrs):
        full_name = attrs.get("full_name")
        profile_picture = attrs.get("profile_picture")

        if self.instance is not None:
            if full_name is None:
                full_name = self.instance.full_name
            if profile_picture is None:
                profile_picture = self.instance.profile_picture

        if not str(full_name or "").strip():
            raise serializers.ValidationError({"full_name": "This field is required."})

        if not profile_picture:
            raise serializers.ValidationError(
                {"profile_picture": "Driver profile picture is required."}
            )

        return attrs


# ---------------------------------------------------------------------------
# Passenger profile
# ---------------------------------------------------------------------------

class PassengerProfileSerializer(serializers.ModelSerializer):
    """
    Create or update a passenger profile.

    Requirements:
      - full_name is required
      - profile_picture is optional
      - card fields are optional
    """
    profile_picture = serializers.ImageField(write_only=True, required=False)
    profile_picture_url = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = PassengerProfile
        fields = [
            "id",
            "full_name",
            "profile_picture",
            "profile_picture_url",
            "card_holder_name",
            "card_last4",
            "card_expiry_mm_yy",
        ]
        read_only_fields = ["id"]

    def get_profile_picture_url(self, obj):
        request = self.context.get("request")
        if not obj.profile_picture:
            return ""
        url = obj.profile_picture.url
        return request.build_absolute_uri(url) if request else url

    def validate_full_name(self, value):
        if not str(value or "").strip():
            raise serializers.ValidationError("This field is required.")
        return value.strip()

    def validate_card_last4(self, value):
        if value and (len(value) != 4 or not value.isdigit()):
            raise serializers.ValidationError("Use exactly 4 digits.")
        return value

    def validate_card_expiry_mm_yy(self, value):
        if not value:
            return value
        if len(value) != 5 or value[2] != "/":
            raise serializers.ValidationError("Use MM/YY format.")
        mm, yy = value.split("/")
        if not (mm.isdigit() and yy.isdigit()):
            raise serializers.ValidationError("Use MM/YY format.")
        month = int(mm)
        if month < 1 or month > 12:
            raise serializers.ValidationError("Month must be between 01 and 12.")
        return value


# ---------------------------------------------------------------------------
# User representations
# ---------------------------------------------------------------------------

class DriverPublicSerializer(serializers.ModelSerializer):
    """
    Driver info embedded in Ride responses for passengers.
    Includes the driver's user `id` so the frontend can submit a review.
    """

    full_name = serializers.CharField(source="driver_profile.full_name", read_only=True)
    profile_picture_url = serializers.SerializerMethodField(read_only=True)
    car_model = serializers.CharField(
        source="driver_profile.car_model", read_only=True, default=None
    )
    plate_number = serializers.CharField(
        source="driver_profile.plate_number", read_only=True, default=None
    )

    class Meta:
        model = User
        fields = [
            "id",
            "phone_number",
            "full_name",
            "profile_picture_url",
            "car_model",
            "plate_number",
        ]

    def get_profile_picture_url(self, obj):
        request = self.context.get("request")
        try:
            pic = obj.driver_profile.profile_picture
        except Exception:
            return ""
        if not pic:
            return ""
        url = pic.url
        return request.build_absolute_uri(url) if request else url


class UserMeSerializer(serializers.ModelSerializer):
    """
    Authenticated user profile (/users/me/).
    """

    driver_profile = DriverProfileSerializer(read_only=True)
    passenger_profile = PassengerProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "phone_number",
            "role",
            "is_verified",
            "date_joined",
            "driver_profile",
            "passenger_profile",
        ]
        read_only_fields = fields
