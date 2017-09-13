With

/* Degree strings */
degs As (
  Select id_number, stewardship_years As yrs
  From table(ksm_pkg.tbl_entity_degrees_concat_ksm) deg
),

/* Household data */
hh As (
  Select hhs.*,
    entity.gender_code As gender, entity_s.gender_code As gender_spouse,
    entity.person_or_org, entity.record_status_code As record_status, entity_s.record_status_code As record_status_spouse,
    -- First Middle Last Suffix 'YY
    trim(
      trim(
      trim(trim(trim(trim(entity.first_name) || ' ' || trim(entity.middle_name)) || ' ' || trim(entity.last_name)) || ' ' || entity.pers_suffix)
      || ' ' || degs.yrs)
      || (Case When entity.record_status_code = 'D' Then '<DECEASED>' End)
    ) As primary_name,
    trim(
      trim(
      trim(trim(trim(trim(entity_s.first_name) || ' ' || trim(entity_s.middle_name)) || ' ' || trim(entity_s.last_name)) || ' ' || entity_s.pers_suffix)
      || ' ' || degs_s.yrs)
      || (Case When entity_s.record_status_code = 'D' Then '<DECEASED>' End)
    ) As primary_name_spouse,
    degs.yrs, degs_s.yrs As yrs_spouse
  From table(ksm_pkg.tbl_entity_households_ksm) hhs
  -- Names and strings for formatting
  Inner Join entity On entity.id_number = hhs.household_id
  Left Join entity entity_s On entity_s.id_number = hhs.household_spouse_id
  Left Join degs On degs.id_number = hhs.household_id
  Left Join degs degs_s On degs_s.id_number = hhs.household_spouse_id
  -- Exclude purgable entities
  Where hhs.record_status_code <> 'X'
),

/* Anonymous */
anon As (
  Select Distinct hh.household_id, tms.short_desc As anon
  From handling
  Inner Join hh On hh.id_number = handling.id_number
  Inner Join tms_handling_type tms On tms.handling_type = handling.hnd_type_code
  Where hnd_type_code = 'AN'
    And hnd_status_code = 'A'
),

/* Deceased spouses */
dec_spouse As (
  Select Distinct id_number, spouse_id_number
  From former_spouse
  Where marital_status_code In (
    Select marital_status_code From tms_marital_status Where lower(short_desc) Like '%death%'
  )
),
dec_spouse_conc As (
  Select id_number,
    Listagg(spouse_id_number, '; ') Within Group (Order By spouse_id_number) As dec_spouse_ids
  From dec_spouse
  Group By id_number
),

/* Prospect assignments */
assign As (
  Select Distinct hh.household_id, assignment.prospect_id, office_code, assignment_id_number, entity.report_name
  From assignment
  Inner Join entity On entity.id_number = assignment.assignment_id_number
  Inner Join prospect_entity On prospect_entity.prospect_id = assignment.prospect_id
  Inner Join hh On hh.id_number = prospect_entity.id_number
  Where active_ind = 'Y'
    And assignment_type In ('PP', 'PM')
),
assign_conc As (
  Select household_id,
    Listagg(report_name, ';  ') Within Group (Order By report_name) As managers
  From assign
  Group By household_id
),

/* KLC entities */
young_klc As (
  Select klc.*
  From table(ksm_pkg.tbl_klc_history) klc
  Where fiscal_year Between 2012 And 2017
),
fy_klc As (
  Select Distinct household_id, '<KLC17>' As klc
  From young_klc
  Where fiscal_year = 2017
),

/* Loyal households */
loyal_giving As (
  Select Distinct hh.household_id,
    -- WARNING: includes new gifts and commitments as well as cash
    sum(Case When fiscal_year = 2017 Then hh_credit Else 0 End) As stewardship_cfy,
    sum(Case When fiscal_year = 2016 Then hh_credit Else 0 End) As stewardship_pfy1,
    sum(Case When fiscal_year = 2015 Then hh_credit Else 0 End) As stewardship_pfy2
  From table(ksm_pkg.tbl_entity_households_ksm) hh
  Cross Join v_current_calendar cal
  Inner Join v_ksm_giving_trans_hh gfts On gfts.household_id = hh.household_id
  Group By hh.household_id
),
loyal As (
  Select loyal_giving.*,
    Case When stewardship_cfy > 0 And stewardship_pfy1 > 0 And stewardship_pfy2 > 0 Then '<LOYAL>' End As loyal
  From loyal_giving
),

/* Campaign giving amounts */
cgft As (
  Select gft.*,
  -- Giving level string
  Case
    When entity.person_or_org = 'O' Then 'Z. Org'
    When campaign_giving >= 10000000 Then 'A. 10M+'
    When campaign_giving >=  5000000 Then 'B. 5M+'
    When campaign_giving >=  2000000 Then 'C. 2M+'
    When campaign_giving >=  1000000 Then 'D. 1M+'
    When campaign_giving >=   500000 Then 'E. 500K+'
    When campaign_giving >=   250000 Then 'F. 250K+'
    When campaign_giving >=   100000 Then 'F. 100K+'
    When campaign_giving >=    50000 Then 'G. 50K+'
    When campaign_giving >=    25000 Then 'H. 25K+'
    When campaign_giving >=    10000 Then 'I. 10K+'
    When campaign_giving >=     5000 Then 'J. 5K+'
    When campaign_giving >=     2500 Then 'K. 2.5K+'
    Else 'L. Under 2.5K'
  End As proposed_giving_level,
  Case
    When entity.person_or_org = 'O' Then 'Z. Org'
    When campaign_nonanonymous >= 10000000 Then 'A. 10M+'
    When campaign_nonanonymous >=  5000000 Then 'B. 5M+'
    When campaign_nonanonymous >=  2000000 Then 'C. 2M+'
    When campaign_nonanonymous >=  1000000 Then 'D. 1M+'
    When campaign_nonanonymous >=   500000 Then 'E. 500K+'
    When campaign_nonanonymous >=   250000 Then 'F. 250K+'
    When campaign_nonanonymous >=   100000 Then 'F. 100K+'
    When campaign_nonanonymous >=    50000 Then 'G. 50K+'
    When campaign_nonanonymous >=    25000 Then 'H. 25K+'
    When campaign_nonanonymous >=    10000 Then 'I. 10K+'
    When campaign_nonanonymous >=     5000 Then 'J. 5K+'
    When campaign_nonanonymous >=     2500 Then 'K. 2.5K+'
    Else 'L. Under 2.5K'
  End As nonanon_giving_level
  From v_ksm_giving_campaign gft
  Inner Join entity On entity.id_number = gft.id_number
),

/* Cash giving amounts */
cash As (
  Select Distinct hh.id_number, hh.household_id, hh.household_rpt_name, hh.household_spouse_id, hh.household_spouse,
    -- Cash giving for KLC young alumni determination
    sum(Case When fiscal_year = 2012 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy12,
    sum(Case When fiscal_year = 2013 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy13,
    sum(Case When fiscal_year = 2014 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy14,
    sum(Case When fiscal_year = 2015 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy15,
    sum(Case When fiscal_year = 2016 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy16,
    sum(Case When fiscal_year = 2017 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy17
  From table(ksm_pkg.tbl_entity_households_ksm) hh
  Inner Join v_ksm_giving_trans_hh gfts On gfts.household_id = hh.household_id
  Group By hh.id_number, hh.household_id, hh.household_rpt_name, hh.household_spouse_id, hh.household_spouse
),

/* Combine all criteria */
donorlist As (
  (
  -- $2500+ cumulative campaign giving
  Select cgft.*, hh.record_status_code, hh.household_suffix, hh.household_spouse_suffix, hh.household_masters_year,
    hh.primary_name, hh.gender, hh.primary_name_spouse, hh.gender_spouse,
    hh.person_or_org, hh.yrs, hh.yrs_spouse
  From cgft
  Inner Join hh On hh.id_number = cgft.id_number
  Where cgft.campaign_giving >= 2500
  ) Union All (
  -- Young alumni giving $1000+ from FY12 on
  Select cgft.*, hh.record_status_code, hh.household_suffix, hh.household_spouse_suffix, hh.household_masters_year,
    hh.primary_name, hh.gender, hh.primary_name_spouse, hh.gender_spouse,
    hh.person_or_org, hh.yrs, hh.yrs_spouse
  From cgft
  Inner Join hh On hh.id_number = cgft.id_number
  Left Join cash On cash.id_number = cgft.id_number
  -- Graduated within "past" 5 years and gave at least $1000 "this" year
  Where cgft.household_id In (Select Distinct household_id From young_klc)
    And (
         ((hh.last_noncert_year Between 2007 And 2012 Or hh.spouse_last_noncert_year Between 2007 And 2012)
          And (campaign_fy12 >= 1000 Or cash_fy12 >= 1000))
      Or ((hh.last_noncert_year Between 2008 And 2013 Or hh.spouse_last_noncert_year Between 2008 And 2013)
          And (campaign_fy13 >= 1000 Or cash_fy13 >= 1000))
      Or ((hh.last_noncert_year Between 2009 And 2014 Or hh.spouse_last_noncert_year Between 2009 And 2014)
          And (campaign_fy14 >= 1000 Or cash_fy14 >= 1000))
      Or ((hh.last_noncert_year Between 2010 And 2015 Or hh.spouse_last_noncert_year Between 2010 And 2015)
          And (campaign_fy15 >= 1000 Or cash_fy15 >= 1000))
      Or ((hh.last_noncert_year Between 2011 And 2016 Or hh.spouse_last_noncert_year Between 2011 And 2016)
          And (campaign_fy16 >= 1000 Or cash_fy16 >= 1000))
      Or ((hh.last_noncert_year Between 2012 And 2017 Or hh.spouse_last_noncert_year Between 2012 And 2017)
          And (campaign_fy17 >= 1000 Or cash_fy17 >= 1000))
    )
  )
)

/* Main query */
Select Distinct
  -- Recognition string
  -- Anonymous is just Anonymous
  Case When anon.anon Is Not Null Then 'Anonymous'
  Else
    -- All others
    (Case
      -- Orgs get their full name
      When person_or_org = 'O' Then household_rpt_name
      -- If no spouse, use own name
      When primary_name_spouse Is Null Then trim(primary_name)
      -- If spouse, check if either/both have degrees
      When primary_name_spouse Is Not Null Then
        Case
          -- If primary is only one with degrees, order is primary spouse
          When yrs Is Not Null And yrs_spouse Is Null Then primary_name || ' and ' || primary_name_spouse
          -- If spouse is only one with degrees, order is spouse primary
          When yrs Is Null And yrs_spouse Is Not Null Then primary_name_spouse || ' and ' || primary_name
          -- Check gender
          Else Case
            -- If primary is female list primary first
            When gender = 'F' Then primary_name || ' and ' || primary_name_spouse
            -- If spouse is female list spouse first
            When gender_spouse = 'F' Then primary_name_spouse || ' and ' || primary_name
            -- Fallback
            Else primary_name || ' and ' || primary_name_spouse
          End
        End
    End
  -- Add loyal tag if applicable
    || loyal.loyal
  -- Add KLC tag if applicable
    || fy_klc.klc)
  End As proposed_recognition_name,
  -- Giving level string
  proposed_giving_level,
  -- Anonymous flags
  Case When proposed_giving_level <> nonanon_giving_level And anon.anon Is Null Then 'Y' End As different_nonanon_level,
  anon.anon,
  campaign_anonymous,
  campaign_nonanonymous,
  -- Fields
  campaign_giving,
  assign_conc.managers,
  donorlist.id_number,
  report_name,
  degrees_concat,
  dec_spouse_conc.dec_spouse_ids,
  donorlist.household_id,
  person_or_org,
  record_status_code,
  household_rpt_name,
  household_suffix,
  primary_name,
  yrs,
  gender,
  household_masters_year,
  household_spouse_id,
  household_spouse,
  household_spouse_suffix,
  primary_name_spouse,
  yrs_spouse,
  gender_spouse,
  loyal.stewardship_cfy,
  loyal.stewardship_pfy1,
  loyal.stewardship_pfy2,
  campaign_reachbacks,
  campaign_fy08,
  campaign_fy09,
  campaign_fy10,
  campaign_fy11,
  campaign_fy12,
  campaign_fy13,
  campaign_fy14,
  campaign_fy15,
  campaign_fy16,
  campaign_fy17
From donorlist
Left Join assign_conc On assign_conc.household_id = donorlist.household_id
Left Join dec_spouse_conc On dec_spouse_conc.id_number = donorlist.id_number
Left Join fy_klc On fy_klc.household_id = donorlist.household_id
Left Join loyal On loyal.household_id = donorlist.household_id
Left Join anon On anon.household_id = donorlist.household_id
Order By proposed_giving_level Asc, household_rpt_name Asc