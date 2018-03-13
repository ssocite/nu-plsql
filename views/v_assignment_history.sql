/**************************************
NU historical assignments, including inactive
**************************************/

Create Or Replace View v_assignment_history As

Select
  assignment.prospect_id
  , prospect_entity.id_number
  , entity.report_name
  , prospect_entity.primary_ind
  , assignment.assignment_id
  , assignment.assignment_type
  , tms_at.short_desc As assignment_type_desc
  , trunc(assignment.start_date) As start_date
  , trunc(assignment.stop_date) As stop_date
  -- Calculated start date: use date_added if start_date unavailable
  , Case
      When assignment.start_date Is Not Null Then trunc(assignment.start_date)
      Else trunc(assignment.date_added)
    End As start_dt_calc
  -- Calculated stop date: use date_modified if stop_date unavailable
  , Case
      When assignment.stop_date Is Not Null Then trunc(assignment.stop_date)
      When assignment.active_ind <> 'Y' Then trunc(assignment.date_modified)
      Else NULL
    End As stop_dt_calc
  -- Active or inactive assignment
  , assignment.active_ind As assignment_active_ind
  -- Active or inactive computation
  , Case
      When assignment.active_ind = 'Y' And assignment.stop_date Is Null Then 'Active'
      When assignment.active_ind = 'Y' And assignment.stop_date > cal.yesterday Then 'Active'
      Else 'Inactive'
    End As assignment_active_calc
  , assignment.assignment_id_number
  , assignee.report_name As assignment_report_name
  , assignment.xcomment As description
From assignment
Cross Join v_current_calendar cal
Inner Join tms_assignment_type tms_at On tms_at.assignment_type = assignment.assignment_type
Inner Join entity assignee On assignee.id_number = assignment.assignment_id_number
Inner Join prospect_entity On prospect_entity.prospect_id = assignment.prospect_id
Inner Join entity On entity.id_number = prospect_entity.id_number
