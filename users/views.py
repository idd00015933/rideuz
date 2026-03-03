import random
import string

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DriverProfile, PassengerProfile
from .permissions import IsDriver, IsPassenger, IsVerifiedUser
from .serializers import (
    DriverProfileSerializer,
    OTPVerifySerializer,
    PassengerProfileSerializer,
    RegisterSerializer,
    RoleSelectSerializer,
    UserMeSerializer,
)

User = get_user_model()


def _generate_otp() -> str:
    """Generate a 6-digit numeric OTP."""
    return "".join(random.choices(string.digits, k=6))


# ---------------------------------------------------------------------------
# Authentication flow  (AllowAny — no token required)
# ---------------------------------------------------------------------------

class RegisterView(APIView):
    """
    POST /api/auth/register/

    Step 1 of 3 — Submit phone number to begin registration.
    Creates a new unverified user (or refreshes the OTP for an existing
    unverified one).  Returns the OTP in the response body for demo/mock
    purposes only — in production this would be sent via SMS and NEVER
    returned to the client.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        phone_number = serializer.validated_data["phone_number"]
        user, created = User.objects.get_or_create(phone_number=phone_number)

        # Whether this is a new user or an already-verified returning user,
        # we always generate a fresh OTP and return it.  This makes the
        # register endpoint double as the "send login OTP" endpoint so the
        # Flutter client only needs one call regardless of user state.
        otp = _generate_otp()
        user.otp_code = otp
        user.otp_created_at = timezone.now()
        user.save(update_fields=["otp_code", "otp_created_at"])

        return Response(
            {
                "phone_number": user.phone_number,
                "otp_code": otp,  # DEMO ONLY — remove in production
                "detail": "OTP sent. Submit it to /api/auth/verify-otp/ within 5 minutes.",
            },
            status=status.HTTP_200_OK,
        )


class OTPVerifyView(APIView):
    """
    POST /api/auth/verify-otp/

    Step 2 of 3 — Submit phone_number + otp_code.
    On success: marks the user as verified, clears OTP fields, and returns
    an auth token that must be sent as `Authorization: Token <key>` on all
    subsequent requests.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        phone_number = serializer.validated_data["phone_number"]
        otp_code     = serializer.validated_data["otp_code"]

        try:
            user = User.objects.get(phone_number=phone_number)
        except User.DoesNotExist:
            return Response(
                {"detail": "No account found for this phone number."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if user.otp_code != otp_code:
            return Response(
                {"detail": "Invalid OTP code."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not user.is_otp_valid:
            return Response(
                {"detail": "OTP has expired. Please request a new one via /api/auth/register/."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify the user and clear OTP fields atomically
        user.is_verified   = True
        user.otp_code      = None
        user.otp_created_at = None
        user.save(update_fields=["is_verified", "otp_code", "otp_created_at"])

        token, _ = Token.objects.get_or_create(user=user)

        return Response(
            {
                "token": token.key,
                "phone_number": user.phone_number,
                "role": user.role,
                "detail": "Verification successful. Use the token for all future requests.",
            },
            status=status.HTTP_200_OK,
        )


class RoleSelectView(APIView):
    """
    POST /api/auth/select-role/

    Step 3 of 3 — Verified user picks PASSENGER or DRIVER.
    Role is permanent once set; a second call is rejected.
    Requires:  Authorization: Token <key>
    """
    permission_classes = [IsVerifiedUser]

    def post(self, request):
        if request.user.role:
            return Response(
                {"detail": f"Role is already set to '{request.user.role}' and cannot be changed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = RoleSelectSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        request.user.role = serializer.validated_data["role"]
        request.user.save(update_fields=["role"])

        return Response(UserMeSerializer(request.user).data, status=status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# User profile  (IsVerifiedUser required)
# ---------------------------------------------------------------------------

class UserMeView(APIView):
    """
    GET /api/users/me/

    Returns the authenticated user's own profile.
    Sensitive fields (otp, password, is_blocked, is_staff) are excluded by
    the serializer.
    """
    permission_classes = [IsVerifiedUser]

    def get(self, request):
        return Response(UserMeSerializer(request.user).data)


# ---------------------------------------------------------------------------
# Driver profile  (IsDriver required)
# ---------------------------------------------------------------------------

class DriverProfileView(APIView):
    """
    GET  /api/users/driver-profile/  — Retrieve own driver profile
    POST /api/users/driver-profile/  — Create driver profile (first-time setup)
    PATCH /api/users/driver-profile/ — Update car details or toggle is_online
    """
    permission_classes = [IsDriver]

    def _get_profile(self, user):
        """Return the DriverProfile instance or None if it does not exist."""
        try:
            return user.driver_profile
        except DriverProfile.DoesNotExist:
            return None

    def get(self, request):
        profile = self._get_profile(request.user)
        if not profile:
            return Response(
                {"detail": "Driver profile not found. Create one with POST."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(DriverProfileSerializer(profile).data)

    def post(self, request):
        if self._get_profile(request.user):
            return Response(
                {"detail": "Profile already exists. Use PATCH to update it."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = DriverProfileSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def patch(self, request):
        profile = self._get_profile(request.user)
        if not profile:
            return Response(
                {"detail": "Driver profile not found. Create one with POST."},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = DriverProfileSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


# ---------------------------------------------------------------------------
# Passenger profile  (IsPassenger required)
# ---------------------------------------------------------------------------

class PassengerProfileView(APIView):
    """
    GET  /api/users/passenger-profile/  - Retrieve own passenger profile
    POST /api/users/passenger-profile/  - Create passenger profile
    PATCH /api/users/passenger-profile/ - Update passenger profile
    """
    permission_classes = [IsPassenger]

    def _get_profile(self, user):
        try:
            return user.passenger_profile
        except PassengerProfile.DoesNotExist:
            return None

    def get(self, request):
        profile = self._get_profile(request.user)
        if not profile:
            return Response(
                {"detail": "Passenger profile not found. Create one with POST."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(PassengerProfileSerializer(profile).data)

    def post(self, request):
        if self._get_profile(request.user):
            return Response(
                {"detail": "Profile already exists. Use PATCH to update it."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = PassengerProfileSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def patch(self, request):
        profile = self._get_profile(request.user)
        if not profile:
            return Response(
                {"detail": "Passenger profile not found. Create one with POST."},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = PassengerProfileSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
