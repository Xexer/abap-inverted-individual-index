CLASS zcl_bs_perf_table_measure DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    TYPES identifiers TYPE STANDARD TABLE OF zbs_perf_tab_a-identifier WITH EMPTY KEY.
    TYPES currencies  TYPE STANDARD TABLE OF zbs_perf_tab_a-currency WITH EMPTY KEY.
    TYPES numbers     TYPE STANDARD TABLE OF zbs_perf_tab_a-number_value WITH EMPTY KEY.
    TYPES table_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    TYPES full_lines  TYPE STANDARD TABLE OF zbs_perf_tab_a WITH EMPTY KEY.

    TYPES: BEGIN OF key_text,
             identifier  TYPE zbs_perf_tab_a-identifier,
             description TYPE zbs_perf_tab_a-description,
           END OF key_text.
    TYPES key_texts TYPE STANDARD TABLE OF key_text WITH EMPTY KEY.

    TYPES: BEGIN OF currency_total,
             currency     TYPE zbs_perf_tab_a-currency,
             line_count   TYPE i,
             total_amount TYPE zbs_perf_tab_a-amount,
           END OF currency_total.
    TYPES currency_totals TYPE STANDARD TABLE OF currency_total WITH EMPTY KEY.

    TYPES: BEGIN OF key_range,
             low  TYPE zbs_perf_tab_a-identifier,
             high TYPE zbs_perf_tab_a-identifier,
           END OF key_range.
    TYPES key_ranges TYPE STANDARD TABLE OF key_range WITH EMPTY KEY.

    TYPES: BEGIN OF measurement,
             scenario   TYPE string,
             table_name TYPE string,
             executions TYPE i,
             hits       TYPE i,
             seconds    TYPE decfloat34,
           END OF measurement.
    TYPES measurements TYPE STANDARD TABLE OF measurement WITH EMPTY KEY.

    CONSTANTS key_reads       TYPE i VALUE 10000.
    CONSTANTS group_reads     TYPE i VALUE 20.
    CONSTANTS non_key_reads   TYPE i VALUE 1000.
    CONSTANTS aggregate_reads TYPE i VALUE 1000.
    CONSTANTS range_reads     TYPE i VALUE 1000.

    "! Builds the keys for the key access, alternating existing and non-existing keys
    "! @parameter result        | Keys to read
    "! @raising   cx_uuid_error | Non-existing key could not be created
    METHODS build_test_keys
      RETURNING VALUE(result) TYPE identifiers
      RAISING   cx_uuid_error.

    "! Reads all currencies used in the test data
    "! @parameter result | Distinct currencies
    METHODS read_currencies
      RETURNING VALUE(result) TYPE currencies.

    "! Builds random numbers for the non-key access
    "! @parameter result | Numbers to search for
    METHODS build_search_numbers
      RETURNING VALUE(result) TYPE numbers.

    "! Builds key ranges with different widths, including ranges without hits
    "! @parameter result | Key ranges to read
    METHODS build_key_ranges
      RETURNING VALUE(result) TYPE key_ranges.

    "! Scenario 1: reads key and short text by primary key
    "! @parameter table_name | Table to read
    "! @parameter keys       | Keys to read
    "! @parameter result     | Measurement
    METHODS measure_key_access
      IMPORTING table_name    TYPE string
                !keys         TYPE identifiers
      RETURNING VALUE(result) TYPE measurement.

    "! Scenario 2a: reads full lines per currency
    "! @parameter table_name | Table to read
    "! @parameter currencies | Currencies to group by
    "! @parameter result     | Measurement
    METHODS measure_group_access
      IMPORTING table_name    TYPE string
                currencies    TYPE currencies
      RETURNING VALUE(result) TYPE measurement.

    "! Scenario 2b: aggregates count and amount with GROUP BY currency
    "! @parameter table_name | Table to read
    "! @parameter result     | Measurement
    METHODS measure_group_by_aggregate
      IMPORTING table_name    TYPE string
      RETURNING VALUE(result) TYPE measurement.

    "! Scenario 4: reads key and short text with BETWEEN on the primary key
    "! @parameter table_name | Table to read
    "! @parameter key_ranges | Key ranges to read
    "! @parameter result     | Measurement
    METHODS measure_key_range_access
      IMPORTING table_name    TYPE string
                key_ranges    TYPE key_ranges
      RETURNING VALUE(result) TYPE measurement.

    "! Scenario 3: reads key and short text by a non-key field
    "! @parameter table_name | Table to read
    "! @parameter numbers    | Numbers to search for
    "! @parameter result     | Measurement
    METHODS measure_non_key_access
      IMPORTING table_name    TYPE string
                numbers       TYPE numbers
      RETURNING VALUE(result) TYPE measurement.

    "! Calculates the elapsed time since the start
    "! @parameter start  | Start timestamp
    "! @parameter result | Elapsed seconds
    METHODS elapsed_seconds
      IMPORTING !start        TYPE utclong
      RETURNING VALUE(result) TYPE decfloat34.
ENDCLASS.


CLASS zcl_bs_perf_table_measure IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA measurements TYPE measurements.

    TRY.
        DATA(keys) = build_test_keys( ).
      CATCH cx_uuid_error INTO DATA(error).
        out->write( error->get_text( ) ).
        RETURN.
    ENDTRY.

    DATA(currencies) = read_currencies( ).
    DATA(numbers) = build_search_numbers( ).
    DATA(key_ranges) = build_key_ranges( ).

    DATA(table_names) = VALUE table_names( ( `ZBS_PERF_TAB_A` )
                                           ( `ZBS_PERF_TAB_B` ) ).

    LOOP AT table_names INTO DATA(table_name).
      INSERT measure_key_access( table_name = table_name
                                 keys       = keys ) INTO TABLE measurements.
      INSERT measure_group_access( table_name = table_name
                                   currencies = currencies ) INTO TABLE measurements.
      INSERT measure_group_by_aggregate( table_name ) INTO TABLE measurements.
      INSERT measure_non_key_access( table_name = table_name
                                     numbers    = numbers ) INTO TABLE measurements.
      INSERT measure_key_range_access( table_name = table_name
                                       key_ranges = key_ranges ) INTO TABLE measurements.
    ENDLOOP.

    SORT measurements BY scenario table_name.
    out->write( measurements ).
  ENDMETHOD.


  METHOD build_test_keys.
    SELECT identifier FROM zbs_perf_tab_a
      ORDER BY identifier
      INTO TABLE @DATA(existing_keys)
      UP TO @key_reads ROWS.

    DO key_reads TIMES.
      IF sy-index MOD 2 = 1 AND existing_keys IS NOT INITIAL.
        INSERT existing_keys[ ( sy-index DIV 2 ) MOD lines( existing_keys ) + 1 ]-identifier INTO TABLE result.
      ELSE.
        INSERT cl_system_uuid=>create_uuid_c32_static( ) INTO TABLE result.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD read_currencies.
    SELECT DISTINCT currency FROM zbs_perf_tab_a
      INTO TABLE @result.
  ENDMETHOD.


  METHOD build_search_numbers.
    DATA(random_number) = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                      min  = 1
                                                      max  = 1000000 ).
    DO non_key_reads TIMES.
      INSERT random_number->get_next( ) INTO TABLE result.
    ENDDO.
  ENDMETHOD.


  METHOD measure_key_access.
    " TODO: variable is assigned but never used (ABAP cleaner)
    DATA key_text TYPE key_text.

    result = VALUE #( scenario   = `1 Key access (key + text)`
                      table_name = table_name
                      executions = lines( keys ) ).

    DATA(start) = utclong_current( ).
    LOOP AT keys INTO DATA(key).
      SELECT SINGLE identifier, description
        FROM (table_name)
        WHERE identifier = @key
        INTO @key_text.
      IF sy-subrc = 0.
        result-hits += 1.
      ENDIF.
    ENDLOOP.
    result-seconds = elapsed_seconds( start ).
  ENDMETHOD.


  METHOD measure_group_access.
    DATA full_lines TYPE full_lines.

    result = VALUE #( scenario   = `2a Full lines per currency`
                      table_name = table_name
                      executions = group_reads * lines( currencies ) ).

    DATA(start) = utclong_current( ).
    DO group_reads TIMES.
      LOOP AT currencies INTO DATA(currency).
        SELECT *
          FROM (table_name)
          WHERE currency = @currency
          INTO TABLE @full_lines.
        result-hits += lines( full_lines ).
      ENDLOOP.
    ENDDO.
    result-seconds = elapsed_seconds( start ).
  ENDMETHOD.


  METHOD build_key_ranges.
    SELECT identifier FROM zbs_perf_tab_a
      ORDER BY identifier
      INTO TABLE @DATA(sorted_keys).

    IF sorted_keys IS INITIAL.
      RETURN.
    ENDIF.

    DATA(key_count) = lines( sorted_keys ).
    DO range_reads TIMES.
      DATA(width) = SWITCH i( sy-index MOD 5
                              WHEN 0 THEN 0
                              WHEN 1 THEN 10
                              WHEN 2 THEN 100
                              WHEN 3 THEN 1000
                              ELSE        5000 ).
      IF width = 0.
        INSERT VALUE #( low  = `G0000000000000000000000000000000`
                        high = `GFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF` ) INTO TABLE result.
        CONTINUE.
      ENDIF.

      DATA(low_index) = ( sy-index * 37 ) MOD key_count + 1.
      DATA(high_index) = nmin( val1 = low_index + width - 1
                               val2 = key_count ).
      INSERT VALUE #( low  = sorted_keys[ low_index ]-identifier
                      high = sorted_keys[ high_index ]-identifier ) INTO TABLE result.
    ENDDO.
  ENDMETHOD.


  METHOD measure_group_by_aggregate.
    DATA currency_totals TYPE currency_totals.

    result = VALUE #( scenario   = `2b GROUP BY currency (aggregate)`
                      table_name = table_name
                      executions = aggregate_reads ).

    DATA(start) = utclong_current( ).
    DO aggregate_reads TIMES.
      SELECT currency,
             COUNT(*)      AS line_count,
             SUM( amount ) AS total_amount
        FROM (table_name)
        GROUP BY currency
        INTO TABLE @currency_totals.
      result-hits += lines( currency_totals ).
    ENDDO.
    result-seconds = elapsed_seconds( start ).
  ENDMETHOD.


  METHOD measure_key_range_access.
    DATA key_texts TYPE key_texts.

    result = VALUE #( scenario   = `4 BETWEEN on key (ranges)`
                      table_name = table_name
                      executions = lines( key_ranges ) ).

    DATA(start) = utclong_current( ).
    LOOP AT key_ranges INTO DATA(key_range).
      SELECT identifier, description
        FROM (table_name)
        WHERE identifier BETWEEN @key_range-low AND @key_range-high
        INTO TABLE @key_texts.
      result-hits += lines( key_texts ).
    ENDLOOP.
    result-seconds = elapsed_seconds( start ).
  ENDMETHOD.


  METHOD measure_non_key_access.
    " TODO: variable is assigned but never used (ABAP cleaner)
    DATA key_text TYPE key_text.

    result = VALUE #( scenario   = `3 Non-key access (number)`
                      table_name = table_name
                      executions = lines( numbers ) ).

    DATA(start) = utclong_current( ).
    LOOP AT numbers INTO DATA(number).
      SELECT SINGLE identifier, description
        FROM (table_name)
        WHERE number_value = @number
        INTO @key_text.
      IF sy-subrc = 0.
        result-hits += 1.
      ENDIF.
    ENDLOOP.
    result-seconds = elapsed_seconds( start ).
  ENDMETHOD.


  METHOD elapsed_seconds.
    result = utclong_diff( high = utclong_current( )
                           low  = start ).
  ENDMETHOD.
ENDCLASS.

