from django.contrib import admin

from .models import Complaint, Review, Ride, RideBooking, Seat


@admin.register(Ride)
class RideAdmin(admin.ModelAdmin):
    list_display = ("id", "driver", "origin", "destination", "departure_time",
                    "price_per_seat", "total_seats", "available_seats", "status")
    list_filter = ("status", "payment_method")
    search_fields = ("origin", "destination", "driver__phone_number")
    date_hierarchy = "departure_time"


@admin.register(Seat)
class SeatAdmin(admin.ModelAdmin):
    list_display = ("id", "ride", "position", "is_available")
    list_filter = ("is_available", "position")


@admin.register(RideBooking)
class RideBookingAdmin(admin.ModelAdmin):
    list_display = ("id", "ride", "passenger", "seat", "payment_method", "status", "booked_at")
    list_filter = ("status", "payment_method")
    search_fields = ("passenger__phone_number",)


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ("id", "ride", "reviewer", "reviewee", "rating", "created_at")
    list_filter = ("rating",)
    search_fields = ("reviewer__phone_number", "reviewee__phone_number")


@admin.register(Complaint)
class ComplaintAdmin(admin.ModelAdmin):
    list_display = ("id", "ride", "filed_by", "created_at")
    search_fields = ("filed_by__phone_number", "description")
