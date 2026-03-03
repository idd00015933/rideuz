from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register("rides",      views.RideViewSet,      basename="ride")
router.register("bookings",   views.BookingViewSet,    basename="booking")
router.register("reviews",    views.ReviewViewSet,     basename="review")
router.register("complaints", views.ComplaintViewSet,  basename="complaint")

urlpatterns = [
    path("maps/reverse/", views.ReverseGeocodeView.as_view(), name="maps-reverse-geocode"),
    path("", include(router.urls)),
]
