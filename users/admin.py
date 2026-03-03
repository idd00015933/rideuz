from django.contrib import admin

from .models import DriverProfile, PassengerProfile, User


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("id", "phone_number", "role", "is_verified", "is_blocked", "is_staff")
    list_filter = ("role", "is_verified", "is_blocked", "is_staff")
    search_fields = ("phone_number",)


@admin.register(DriverProfile)
class DriverProfileAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "full_name", "plate_number", "is_online")
    list_filter = ("is_online",)
    search_fields = ("user__phone_number", "full_name", "plate_number", "car_model")


@admin.register(PassengerProfile)
class PassengerProfileAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "full_name", "card_last4")
    search_fields = ("user__phone_number", "full_name", "card_last4")
