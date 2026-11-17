-- yeGamo migration 0011: prevent duplicate pending leave alerts.
-- One scheduled alert per user and journey plan, and one per routine and instant.

CREATE UNIQUE INDEX leave_alerts_one_scheduled_per_plan_idx
    ON leave_alerts (user_id, journey_plan_id)
    WHERE status = 'SCHEDULED' AND journey_plan_id IS NOT NULL;

CREATE UNIQUE INDEX leave_alerts_one_scheduled_per_routine_idx
    ON leave_alerts (user_id, commute_profile_id, scheduled_for)
    WHERE status = 'SCHEDULED' AND commute_profile_id IS NOT NULL;
