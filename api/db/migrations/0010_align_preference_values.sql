-- yeGamo migration 0010: the API contract accepts LESS_WALKING and FEWER_TRANSFERS
-- for user and routine preferences, but migrations 0002/0005 only allowed LOW_WALK,
-- so PATCH /me/preferences and routine creation failed with a constraint error (500).

ALTER TABLE user_preferences DROP CONSTRAINT user_preferences_travel_preference_check;
ALTER TABLE user_preferences ADD CONSTRAINT user_preferences_travel_preference_check
    CHECK (travel_preference IN (
        'FASTEST', 'RELIABLE', 'BALANCED', 'LESS_WALKING', 'FEWER_TRANSFERS', 'LOW_WALK'
    ));

ALTER TABLE commute_profiles DROP CONSTRAINT commute_profiles_preference_check;
ALTER TABLE commute_profiles ADD CONSTRAINT commute_profiles_preference_check
    CHECK (preference IN (
        'FASTEST', 'RELIABLE', 'BALANCED', 'LESS_WALKING', 'FEWER_TRANSFERS', 'LOW_WALK'
    ));
