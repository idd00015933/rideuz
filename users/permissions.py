from rest_framework.permissions import BasePermission


class IsVerifiedUser(BasePermission):
    """
    Grants access only to authenticated users who have completed OTP verification.
    This is the baseline permission used across all protected endpoints.
    """
    message = "Your phone number must be verified before performing this action."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.is_verified
        )


class IsPassenger(IsVerifiedUser):
    """
    Restricts access to verified users with the PASSENGER role.
    Used on ride creation endpoints.
    """
    message = "This action is restricted to Passengers."

    def has_permission(self, request, view):
        return super().has_permission(request, view) and request.user.role == "PASSENGER"


class IsDriver(IsVerifiedUser):
    """
    Restricts access to verified users with the DRIVER role.
    Used on ride accept/start/complete endpoints and driver profile management.
    """
    message = "This action is restricted to Drivers."

    def has_permission(self, request, view):
        return super().has_permission(request, view) and request.user.role == "DRIVER"
