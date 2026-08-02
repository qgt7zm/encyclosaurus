from django.db import models

class Clade(models.Model):
    name = models.CharField(max_length=100, unique=True)
    rank = models.CharField(max_length=100, default='Clade')
    parent = models.ForeignKey('self', null=True, blank=True, on_delete=models.CASCADE)
    
    def __str__(self):
        return self.name

class Dinosaur(models.Model):
    genus = models.CharField(max_length=100)
    species = models.CharField(max_length=100)
    clade = models.ForeignKey(Clade, null=True, blank=True, on_delete=models.SET_NULL)
    status = models.CharField(max_length=100)
    discoverer_name = models.CharField(max_length=100)
    discoverer_year = models.IntegerField()
    range_start = models.FloatField()
    range_end = models.FloatField()
    weight = models.FloatField()
    length = models.FloatField()
    gait = models.CharField(max_length=100)
    habitat = models.CharField(max_length=100)
    diet = models.CharField(max_length=100)
    notes = models.TextField()
    
    def __str__(self):
        return f"{self.genus} {self.species}"
    
class Location(models.Model):
    name = models.CharField(max_length=100, unique=True)
    country = models.CharField(max_length=100)
    continent = models.CharField(max_length=100)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField()
    
    def __str__(self):
        return f"{self.name}, {self.country}"

class DinosaurLocation(models.Model):
    dinosaur = models.ForeignKey(Dinosaur, on_delete=models.CASCADE)
    location = models.ForeignKey(Location, on_delete=models.CASCADE)
    
    class Meta:
        unique_together = ('dinosaur', 'location')

class Request(models.Model):
    researcher = models.ForeignKey('auth.User', on_delete=models.CASCADE)
    last_update_timestamp = models.DateTimeField(auto_now=True)
    status = models.CharField(max_length=10, choices=[
        ('PENDING', 'Pending'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected')
    ], default='PENDING')
    details = models.TextField()
    
    def __str__(self):
        return f"Request #{self.id}: {self.status}"