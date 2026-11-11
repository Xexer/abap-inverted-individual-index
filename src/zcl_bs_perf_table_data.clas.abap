CLASS zcl_bs_perf_table_data DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    TYPES entries_a TYPE STANDARD TABLE OF zbs_perf_tab_a WITH EMPTY KEY.
    TYPES entries_b TYPE STANDARD TABLE OF zbs_perf_tab_b WITH EMPTY KEY.
    TYPES texts     TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    CONSTANTS number_of_entries TYPE i VALUE 20000.

    DATA random_number TYPE REF TO cl_abap_random_int.
    DATA random_amount TYPE REF TO cl_abap_random_int.

    "! Initializes the random generators for numbers and amounts
    METHODS initialize_randomizer.

    "! Generates the configured number of test entries
    "! @parameter result        | Generated entries
    "! @raising   cx_uuid_error | Identifier could not be created
    METHODS generate_entries
      RETURNING VALUE(result) TYPE entries_a
      RAISING   cx_uuid_error.

    "! Creates a single test entry
    "! @parameter index         | Running number of the entry
    "! @parameter result        | Test entry
    "! @raising   cx_uuid_error | Identifier could not be created
    METHODS create_entry
      IMPORTING !index        TYPE i
      RETURNING VALUE(result) TYPE zbs_perf_tab_a
      RAISING   cx_uuid_error.

    "! Creates a random identifier as key
    "! @parameter result        | Random identifier
    "! @raising   cx_uuid_error | Identifier could not be created
    METHODS create_identifier
      RETURNING VALUE(result) TYPE zbs_perf_tab_a-identifier
      RAISING   cx_uuid_error.

    "! Builds an alternating long text with varying length
    "! @parameter index  | Running number of the entry
    "! @parameter result | Long text with a maximum of 2000 characters
    METHODS build_long_text
      IMPORTING !index        TYPE i
      RETURNING VALUE(result) TYPE string.

    "! Returns an alternating short description
    "! @parameter index  | Running number of the entry
    "! @parameter result | Short description
    METHODS get_description
      IMPORTING !index        TYPE i
      RETURNING VALUE(result) TYPE zbs_perf_tab_a-description.

    "! Returns an alternating currency
    "! @parameter index  | Running number of the entry
    "! @parameter result | Currency key
    METHODS get_currency
      IMPORTING !index        TYPE i
      RETURNING VALUE(result) TYPE zbs_perf_tab_a-currency.

    "! Picks an entry from a list based on the running number
    "! @parameter index  | Running number of the entry
    "! @parameter texts  | List of texts
    "! @parameter result | Selected text
    METHODS pick_alternating
      IMPORTING !index        TYPE i
                texts         TYPE texts
      RETURNING VALUE(result) TYPE string.

    "! Replaces the content of both tables with the same entries
    "! @parameter entries | Entries to save
    METHODS save_entries
      IMPORTING !entries TYPE entries_a.
ENDCLASS.


CLASS zcl_bs_perf_table_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    initialize_randomizer( ).

    TRY.
        DATA(entries) = generate_entries( ).
      CATCH cx_uuid_error INTO DATA(error).
        out->write( error->get_text( ) ).
        RETURN.
    ENDTRY.

    save_entries( entries ).
    out->write( |{ lines( entries ) } entries inserted into ZBS_PERF_TAB_A and ZBS_PERF_TAB_B| ).
  ENDMETHOD.


  METHOD initialize_randomizer.
    random_number = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                min  = 1
                                                max  = 1000000 ).
    random_amount = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                min  = 100
                                                max  = 99999999 ).
  ENDMETHOD.


  METHOD generate_entries.
    DO number_of_entries TIMES.
      INSERT create_entry( sy-index ) INTO TABLE result.
    ENDDO.
  ENDMETHOD.


  METHOD create_entry.
    result = VALUE #( identifier   = create_identifier( )
                      long_text    = build_long_text( index )
                      number_value = random_number->get_next( )
                      amount       = random_amount->get_next( ) / 100
                      currency     = get_currency( index )
                      description  = get_description( index ) ).
  ENDMETHOD.


  METHOD create_identifier.
    result = cl_system_uuid=>create_uuid_c32_static( ).
  ENDMETHOD.


  METHOD build_long_text.
    DATA(sentence) = pick_alternating( index = index
                                       texts = VALUE #(
                                           ( `The customer requested a quotation for the standard product range. ` )
                                           ( `Delivery was confirmed by the logistics department for next week. ` )
                                           ( `Invoice has been checked and released for payment by accounting. ` )
                                           ( `The service ticket was closed after the technician visited the site. ` )
                                           ( `Contract conditions were renegotiated and approved by management. ` ) ) ).

    DATA(target_length) = SWITCH i( index MOD 4
                                    WHEN 0 THEN 250
                                    WHEN 1 THEN 500
                                    WHEN 2 THEN 1000
                                    ELSE        2000 ).

    WHILE strlen( result ) < target_length.
      result &&= sentence.
    ENDWHILE.

    result = substring( val = result
                        len = target_length ).
  ENDMETHOD.


  METHOD get_description.
    result = pick_alternating( index = index
                               texts = VALUE #( ( `Quotation for standard products` )
                                                ( `Delivery confirmation` )
                                                ( `Released invoice` )
                                                ( `Closed service ticket` )
                                                ( `Renegotiated contract` )
                                                ( `Open sales order` )
                                                ( `Pending credit memo` ) ) ).
  ENDMETHOD.


  METHOD get_currency.
    result = pick_alternating( index = index
                               texts = VALUE #( ( `EUR` )
                                                ( `USD` )
                                                ( `CHF` )
                                                ( `GBP` ) ) ).
  ENDMETHOD.


  METHOD pick_alternating.
    result = texts[ ( index MOD lines( texts ) ) + 1 ].
  ENDMETHOD.


  METHOD save_entries.
    DATA(entries_b) = CORRESPONDING entries_b( entries ).

    DELETE FROM zbs_perf_tab_a.
    DELETE FROM zbs_perf_tab_b.

    INSERT zbs_perf_tab_a FROM TABLE @entries.
    INSERT zbs_perf_tab_b FROM TABLE @entries_b.

    COMMIT WORK.
  ENDMETHOD.
ENDCLASS.

