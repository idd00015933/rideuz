from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="driverprofile",
            name="full_name",
            field=models.CharField(default="", max_length=100),
        ),
        migrations.AddField(
            model_name="driverprofile",
            name="profile_picture_url",
            field=models.URLField(blank=True, default=""),
        ),
        migrations.CreateModel(
            name="PassengerProfile",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("full_name", models.CharField(max_length=100)),
                ("profile_picture_url", models.URLField(blank=True, default="")),
                ("card_holder_name", models.CharField(blank=True, default="", max_length=100)),
                ("card_last4", models.CharField(blank=True, default="", max_length=4)),
                ("card_expiry_mm_yy", models.CharField(blank=True, default="", max_length=5)),
                (
                    "user",
                    models.OneToOneField(
                        limit_choices_to={"role": "PASSENGER"},
                        on_delete=models.deletion.CASCADE,
                        related_name="passenger_profile",
                        to="users.user",
                    ),
                ),
            ],
            options={
                "verbose_name": "Passenger Profile",
                "verbose_name_plural": "Passenger Profiles",
                "db_table": "passenger_profiles",
            },
        ),
    ]

