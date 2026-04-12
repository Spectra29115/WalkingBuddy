from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, ForeignKey, Enum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import enum

DATABASE_URL = "sqlite:///crowd_data.db"
engine = create_engine(DATABASE_URL, echo=True)
Base = declarative_base()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# ==================== ENUMS ====================
class PreferenceMode(str, enum.Enum):
    COMFORT = "comfort"
    BUDGET = "budget"
    FASTEST = "fastest"

# ==================== MODELS ====================
class Stop(Base):
    __tablename__ = "stops"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    route = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    base_fare = Column(Float, default=0.0)
    
    crowd_reports = relationship("CrowdReport", back_populates="stop")
    journey_legs = relationship("JourneyLeg", back_populates="stop")

class CrowdReport(Base):
    __tablename__ = "crowd_reports"
    id = Column(Integer, primary_key=True, index=True)
    stop_id = Column(Integer, ForeignKey("stops.id"))
    crowd_level = Column(Integer)  # 0=empty, 1=moderate, 2=full
    latitude = Column(Float)
    longitude = Column(Float)
    timestamp = Column(DateTime, default=datetime.utcnow)
    user_id = Column(String, default="demo_user")
    
    stop = relationship("Stop", back_populates="crowd_reports")

class Transport(Base):
    __tablename__ = "transports"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    type = Column(String)  # bus, metro, auto-rickshaw, etc.
    base_fare = Column(Float)
    per_km_fare = Column(Float)
    
    routes = relationship("Route", back_populates="transport")

class Route(Base):
    __tablename__ = "routes"
    id = Column(Integer, primary_key=True, index=True)
    transport_id = Column(Integer, ForeignKey("transports.id"))
    name = Column(String, index=True)
    start_stop_id = Column(Integer, ForeignKey("stops.id"))
    end_stop_id = Column(Integer, ForeignKey("stops.id"))
    total_distance = Column(Float)  # in km
    average_time = Column(Float)  # in minutes
    
    transport = relationship("Transport", back_populates="routes")
    journey_legs = relationship("JourneyLeg", back_populates="route")

class JourneyLeg(Base):
    __tablename__ = "journey_legs"
    id = Column(Integer, primary_key=True, index=True)
    stop_id = Column(Integer, ForeignKey("stops.id"))
    route_id = Column(Integer, ForeignKey("routes.id"))
    order = Column(Integer)  # sequence in route
    distance_from_start = Column(Float)  # cumulative distance in km
    
    stop = relationship("Stop", back_populates="journey_legs")
    route = relationship("Route", back_populates="journey_legs")

class RouteOption(Base):
    __tablename__ = "route_options"
    id = Column(Integer, primary_key=True, index=True)
    start_stop_id = Column(Integer, ForeignKey("stops.id"))
    end_stop_id = Column(Integer, ForeignKey("stops.id"))
    preference_mode = Column(String)  # comfort, budget, fastest
    total_fare = Column(Float)
    estimated_time = Column(Float)  # minutes
    comfort_score = Column(Float)  # 0-1, based on crowd levels
    distance = Column(Float)  # km
    stop_sequence = Column(String)  # JSON: [stop_id, stop_id, ...]
    created_at = Column(DateTime, default=datetime.utcnow)

Base.metadata.create_all(bind=engine)
print("Database tables created: stops + crowd_reports + transports + routes + journey_legs + route_options")