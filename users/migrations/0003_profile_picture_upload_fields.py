from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0002_passenger_profile_and_driver_fields"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="driverprofile",
            name="profile_picture_url",
        ),
        migrations.RemoveField(
            model_name="passengerprofile",
            name="profile_picture_url",
        ),
        migrations.AddField(
            model_name="driverprofile",
            name="profile_picture",
            field=models.ImageField(blank=True, null=True, upload_to="profiles/drivers/"),
        ),
        migrations.AddField(
            model_name="passengerprofile",
            name="profile_picture",
            field=models.ImageField(blank=True, null=True, upload_to="profiles/passengers/"),
        ),
    ]

