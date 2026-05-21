*** Settings ***
Library                         QForce
Library                         String
Resource                        ../resources/common.robot
Suite Setup                     Setup Browser
Suite Teardown                  End suite

*** Variables ***
${AUTH}                         1
${PRODUCT_1_CODE}               CMP-001
${PRODUCT_1_NAME}               Copado Metadata Pipeline
${PRODUCT_1_QUANTITY}           5
${PRODUCT_1_DISCOUNT}           10
${PRODUCT_1_BUNDLES}            Advanced Sandbox Management|Compliance Hub|Premium Support
${PRODUCT_2_CODE}               CE-003
${PRODUCT_2_NAME}               Copado Essentials
${PRODUCT_2_QUANTITY}           15
${PRODUCT_2_DISCOUNT}           20
${PRODUCT_2_BUNDLES}            Premium Support
${PRODUCT_3_CODE}               CRT-004
${PRODUCT_3_NAME}               Copado Robotic Testing
${PRODUCT_3_QUANTITY}           8
${PRODUCT_3_DISCOUNT}           15
${PRODUCT_3_BUNDLES}            Premium Support
${EXPECTED_TOTAL}               68083.21

*** Test Cases ***
CPQ Test - Data Driven Quote Creation
    [Documentation]             CPQ test using hardcoded values.
    ...                         Auth: ${AUTH}
    ...                         Product 1: ${PRODUCT_1_NAME} (${PRODUCT_1_CODE})
    ...                         Product 2: ${PRODUCT_2_NAME} (${PRODUCT_2_CODE})
    ...                         Product 3: ${PRODUCT_3_NAME} (${PRODUCT_3_CODE})
    ...                         Expected Total: ${EXPECTED_TOTAL}
    [Tags]                      CPQ                         DataDriven                  Auth${AUTH}

    # Step 1: Login
    Login With Auth             ${AUTH}
    Navigate To App             LightningSales

    # Step 2: Create Opportunity
    ClickText                   Opportunities
    IsText                      New                         timeout=15
    ClickText                   New
    UseModal                    On
    TypeText                    *Opportunity Name           Test Opp Auth${AUTH}
    ${future_date}=             Get Current Date            result_format=%m/%d/%Y      increment=30 days
    TypeText                    Close Date                  ${future_date}
    PickList                    *Stage                      Prospecting
    ComboBox                    Price Book                  Copado
    ClickText                   Save                        partial_match=False
    UseModal                    Off

    # Step 3: Create Quote
    IsText                      Create Quote                timeout=10
    ${OppId}                    GetRecordIdFromUrl
    ClickText                   Create Quote
    UseModal                    On
    TypeText                    Contract Length             12
    ClickText                   Next

    # Step 4: Navigate to Quote
    ${QuoteNumber}=             GetText                     Q-                          anchor=Quotes
    ClickText                   ${QuoteNumber}              anchor=Quotes
    ClickText                   Show more actions           anchor=New Account
    ClickText                   Edit Lines
    SetConfig                   ShadowDOM                   True

    # Step 5: Add Products
    ClickText                   Add Products
    ClickText                   Suggest
    IsText                      Product Selection           timeout=5
    ClickItem                   checkbox                    anchor=${PRODUCT_1_CODE}    tag=paper-checkbox
    ClickItem                   checkbox                    anchor=${PRODUCT_2_CODE}    tag=paper-checkbox
    ClickItem                   checkbox                    anchor=${PRODUCT_3_CODE}    tag=paper-checkbox
    ClickText                   Select                      partial_match=False
    IsText                      Configure Products          timeout=10

    # Step 6: Configure Product Bundles
    ClickText                   Bundles
    ClickText                   ${PRODUCT_1_NAME}           partial_match=False
    Configure Product Bundles   ${PRODUCT_1_BUNDLES}
    ClickText                   ${PRODUCT_2_NAME}           partial_match=False
    Configure Product Bundles   ${PRODUCT_2_BUNDLES}
    ClickText                   ${PRODUCT_3_NAME}           partial_match=False
    Configure Product Bundles   ${PRODUCT_3_BUNDLES}
    ClickText                   Save
    IsText                      Edit Quote                  timeout=10

    # Step 7: Edit Quote Lines (Quantities and Discounts)
    Edit Quote Line             ${PRODUCT_1_CODE}           Quantity                    ${PRODUCT_1_QUANTITY}
    Edit Quote Line             ${PRODUCT_1_CODE}           Additional Disc.            ${PRODUCT_1_DISCOUNT}
    Edit Quote Line             ${PRODUCT_2_CODE}           Quantity                    ${PRODUCT_2_QUANTITY}
    Edit Quote Line             ${PRODUCT_2_CODE}           Additional Disc.            ${PRODUCT_2_DISCOUNT}
    Edit Quote Line             ${PRODUCT_3_CODE}           Quantity                    ${PRODUCT_3_QUANTITY}
    Edit Quote Line             ${PRODUCT_3_CODE}           Additional Disc.            ${PRODUCT_3_DISCOUNT}

    # Step 8: Calculate and Validate
    ClickText                   Calculate
    Sleep                       1
    #VerifyText                 ${EXPECTED_TOTAL}           anchor=Quote Total
    ClickText                   Save
    Sleep                       2
