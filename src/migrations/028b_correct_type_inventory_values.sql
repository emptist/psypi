UPDATE type_inventory
SET db_values = ARRAY['NETWORK','AUTH','TIMEOUT','SERVER','TRANSPORT','LOGIC','RESOURCE','UNKNOWN'],
    gap_detail = 'dead_letter_queue.error_category has CHECK with 8 values (UPPER_CASE). Same values as tasks.error_category. No ErrorCategory enum. Could share type with tasks.'
WHERE table_name = 'dead_letter_queue' AND column_name = 'error_category';

UPDATE type_inventory
SET db_values = ARRAY['pending','reviewed','resolved','ignored'],
    gap_detail = 'dead_letter_queue.review_status has CHECK with 4 values. No DlqReviewStatus enum.'
WHERE table_name = 'dead_letter_queue' AND column_name = 'review_status';

UPDATE type_inventory
SET db_values = ARRAY['repeated_failure','stuck_task','dlq_threshold','watchdog_kill','consecutive_failures'],
    gap_detail = 'failure_alerts.alert_type has CHECK with 5 values. No AlertType enum.'
WHERE table_name = 'failure_alerts' AND column_name = 'alert_type';

UPDATE type_inventory
SET gap_detail = 'inter_reviews.status has CHECK with 5 values. inter_review.gleam:79 Review struct has status: String. No InterReviewStatus enum. list_reviews() takes status as Option(String) param with no validation.'
WHERE table_name = 'inter_reviews' AND column_name = 'status';

UPDATE type_inventory
SET gap_detail = 'inter_reviews.response_status has CHECK with 5 values. Not directly read by psypi Gleam code but column exists in table used by inter_review module. No ResponseStatus enum.'
WHERE table_name = 'inter_reviews' AND column_name = 'response_status';

UPDATE type_inventory
SET gap_detail = 'inter_reviews.reviewer_type has CHECK with 2 values. Not read by psypi Gleam code. No ReviewerType enum.'
WHERE table_name = 'inter_reviews' AND column_name = 'reviewer_type';
