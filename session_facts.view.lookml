- view: session_facts
  derived_table:
    sortkeys: [session_start_time]
    distkey: session_unique_id
    sql_trigger_value: select date(convert_timezone('pst', getdate() - interval '3 hours')) # update trigger value to desired frequency and timezone
    sql: |
      SELECT 
        all_events.session_id || '-' || all_events.user_id AS session_unique_id,
        user_id,
        row_number() over( partition by user_id order by min(all_events.time)) as session_sequence_number,
        min(all_events.time) AS session_start_time,
        max(all_events.time) AS session_end_time,
        COUNT(*) AS "all_events.count"
      FROM main_production.all_events AS all_events
      
      GROUP BY 1,2

  fields:

  - dimension: session_unique_id
    type: string
    primary_key: true
    hidden: true
    sql: ${TABLE}.session_unique_id

  - dimension: user_id
    type: number
    hidden: true
    sql: ${TABLE}.user_id

  - dimension: session_sequence_number
    type: number
    sql: ${TABLE}.session_sequence_number
  
  - dimension: is_first_session
    type: yesno
    sql: ${session_sequence_number} = 1

  - dimension_group: session_start_time
    type: time
    timeframes: [time, date, week, month, hour_of_day, day_of_week_index]
    sql: ${TABLE}.session_start_time

  - dimension_group: session_end_time
    type: time
    timeframes: [time, date, week, month, hour_of_day, day_of_week_index]
    sql: ${TABLE}.session_end_time
  
  - dimension: session_duration_minutes
    type: number
    sql: extract(epoch from (${TABLE}.session_end_time - ${TABLE}.session_start_time))/60
    value_format_name: decimal_2

  - dimension: event_count
    type: number
    sql: ${TABLE}."all_events.count"
  
  - dimension: is_bounced
    type: yesno
    sql: ${event_count} = 1 # update to definition of bounced session relevant to Heap implementation
  
  - measure: average_events_per_session
    type: average
    sql: ${event_count}
    value_format_name: decimal_1
  
  - measure: average_session_duration_minutes
    type: average
    sql: ${session_duration_minutes}
    value_format_name: decimal_2