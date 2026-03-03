from django.urls import path

from . import views

urlpatterns = [
    # --- Auth flow (no token required) ---
    path("auth/register/",    views.RegisterView.as_view(),   name="auth-register"),
    path("auth/verify-otp/",  views.OTPVerifyView.as_view(),  name="auth-verify-otp"),
    path("auth/select-role/", views.RoleSelectView.as_view(), name="auth-select-role"),

    # --- User profile (token required) ---
    path("users/me/",             views.UserMeView.as_view(),        name="user-me"),
    path("users/driver-profile/", views.DriverProfileView.as_view(), name="driver-profile"),
    path("users/passenger-profile/", views.PassengerProfileView.as_view(), name="passenger-profile"),
]
