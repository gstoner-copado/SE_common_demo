*** Settings ***
Library                         QForce
Library                         String
Library                         DateTime
Library                         QWeb
Library                         QForce
Library                         QVision
Library                         RequestsLibrary
Library                         FakerLibrary
Library                         Collections
Library                         JSONLibrary
Library                         CopadoAI

*** Variables ***
${agent_icon}                   embeddedMessagingIconChat
${chat_expand}                  //button[@title\="Expand the chat window"]
${chat_minimize}                //button[@title\="Minimize chat window"]
${msg_xpath}                    //section[@class\="slds-chat"]/ul//li
${response_portion}             div[contains(@class, "slds-chat-message__text_inbound")]
${BROWSER}                      chrome
${username}                     pace.delivery1@qentinel.com.demonew
${login_url}                    https://qentinel--demonew.my.salesforce.com/            # Salesforce instance. NOTE: Should be overwritten in CRT variables
${home_url}                     ${login_url}/lightning/page/home




*** Keywords ***
Setup Browser
    # Setting search order is not really needed here, but given as an example
    # if you need to use multiple libraries containing keywords with duplicate names
    Set Library Search Order    QForce                      QWeb
    Open Browser                about:blank                 ${BROWSER}
    SetConfig                   LineBreak                   ${EMPTY}                    #\ue000
    Evaluate                    random.seed()               random                      # initialize random generator
    SetConfig                   DefaultTimeout              20s                         #sometimes salesforce is slow
    # adds a delay of 0.3 between keywords. This is helpful in cloud with limited resources.
    SetConfig                   Delay                       0.3

End suite
    Close All Browsers


    
Login
    [Documentation]             Login to Salesforce instance
    GoTo                        ${login_url}
    TypeText                    Username                    ${JGUsername}
    TypeSecret                  Password                    ${JGPass}
    ClickText                   Log In
    ${MFA_needed}=              Run Keyword And Return Status                           Should Not Be Equal         ${None}         ${secret}
    Run Keyword If              ${MFA_needed}               Fill MFA                    ${JGUsername}              ${secret}       ${login_url}


Fill MFA
    [Documentation]             Gets the MFA OTP code and fills the verification dialog (if needed)
    [Arguments]                 ${sf_username}=${username}                              ${mfa_secret}=${secret}     ${sf_instance_url}=${login_url}
    ${mfa_code}=                GetOTP                      ${sf_username}              ${mfa_secret}               ${login_url}
    TypeSecret                  Verification Code           ${mfa_code}
    ClickText                   Verify

    # Agentforce chat navigation custom keywords
    # ------------------------------------------
Expand Agent Chat
    [Documentation]             Expands the agent chat window unless it's already expanded
    # Note: you may need to modify variables in variables section according to your env
    ${expanded}=                IsElement                   ${msg_xpath}

    IF                          ${expanded}
        Log To Console          Agent was already expanded
    ELSE
        ${not_first}=           IsElement                   ${chat_expand}
        # also check 2 different possibilities for "expand"
        IF                      ${not_first}
            ClickElement        ${chat_expand}
        ELSE
            ClickItem           ${agent_icon}               5
            VerifyInputElement                              Type your message...
            Sleep               2                           # wait few extra seconds for chat dialog to open first time
        END
        # verify in order to make sure chat window is fully open
        VerifyElement           ${msg_xpath}                delay=1
    END

Minimize Agent Chat
    [Documentation]             Minimized the agent chat window unless it's already minimized
    # Note: you may need to modify variables in variables section according to your env
    ${expanded}=                IsElement                   ${msg_xpath}
    IF                          ${expanded}
        ClickElement            ${chat_minimize}
    ELSE
        Log To Console          Agent was already minimized
    END


Send Prompt
    [Documentation]             Asks a question from Service agent and returns the reply. Makes sure chat window is expanded before typing.
    [Arguments]                 ${prompt}                   ${timeout}=20
    # Note: you may need to modify variables in variables section according to your env
    Expand Agent Chat
    VerifyInputElement          Type your message...
    ${initial_index}=           Get Last Message Index
    Log To Console              ${initial_index}
    TypeText                    Type your message...        ${prompt}\n                 tag=input



    # Loop until reply is available or timeout reached
    FOR                         ${i}                        IN RANGE                    ${timeout}
        ${current}=             Get Last Message Index
        Run Keyword If          ${current} >= ${initial_index} + 1                      Exit FOR Loop
        IF                      ${i} < ${timeout}
            Sleep               1
        ELSE
            Fail                Could not get reply from agent in ${timeout} seconds
        END
    END

    ${reply}=                   GetText                     (${msg_xpath}//${response_portion})[${current}]

    RETURN                      ${reply}

Get Last Message Index
    [Documentation]             Helper keyword to get last chat message index / count from a chat
    # Note: you may need to modify variables in variables section according to your env
    ${count}=                   GetElementCount             ${msg_xpath}//${response_portion}
    RETURN                      ${count}

Manage Session Records
    [Documentation]             Creates a new session record after deleting any existing sessions for the given date and experience
    ...                         Supports partial name matching (e.g., "Snorkeling" will match "Coral Reef Snorkeling Adventure")
    [Arguments]                 ${date}
    
    JwtAuthenticate             ${AFclient_id}    ${JGUsername}    ${AFprivate_key}

    # Format the date for Salesforce query

    # Query & Delete previous sessions
    ${oldSessionIds}            QueryRecords                SELECT id, Available_Slots__c,Start_Time__c,Experience__c FROM Session__c where Experience__c\='a09Hu00001n2mRYIAY' AND Date__c\=${date}

    # Deleting prior runs sessions
    IF                          ${oldSessionIds}[totalSize] > 0
        FOR                     ${index}                    IN RANGE                    ${oldSessionIds}[totalSize]
            Delete Record       Session__c                  ${oldSessionIds}[records][${index}][Id]
        END
    END

    # Create Session
    ${sessionId}=               Create Record               Session__c                  Experience__c=a09Hu00001n2mRYIAY                        Start_Time__c=00:00:00.000Z    Date__c=${date}

    # Return the created session ID for further use
    RETURN                      ${sessionId}



Authentication         
    Authenticate                ${client_id}                ${client_secret}            ${username}                 ${password}

Query Experience Record
    [Documentation]             Queries Experience__c records by name and returns the results
    ...                         This keyword executes a SOQL query to retrieve Experience records
    ...                         matching the provided experience name.
    ...
    ...                         Arguments:
    ...                         - experienceName: The name of the Experience record to query
    ...
    ...                         Returns:
    ...                         - Query results containing id, Name, Description__c, Activity_Level__c, Type__c
    ...
    ...                         Example:
    ...                         ${results}=                 Query Experience Record     My Experience
    [Arguments]                 ${experienceName}
    ${experienceQuery}=         QueryRecords                SELECT id, Name, Description__c, Activity_Level__c, Type__c FROM Experience__c WHERE Name\='${experienceName}'
    ${id}=                      Set Variable                ${experienceQuery}[records][0][Id]
    [Return]                    ${id}

Query Session Record
    [Documentation]             Queries Session__c records by Experience ID and date
    ...                         This keyword executes a SOQL query to retrieve Session records
    ...                         for a specific Experience and date, returning available slots information.
    ...
    ...                         Arguments:
    ...                         - experienceQuery: The query results from Experience__c query containing records
    ...                         - date: The date to filter sessions (should be in proper Salesforce date format)
    ...
    ...                         Returns:
    ...                         - Query results containing id and Available_Slots__c
    ...
    ...                         Example:
    ...                         ${experienceResults}=       Query Experience Record     My Experience
    ...                         ${sessionResults}=          Query Session Record By Experience And Date             ${experienceResults}        2024-01-15
    [Arguments]                 ${experienceQuery}          ${date}
    ${sessionQuery}=            QueryRecords                SELECT id, Available_Slots__c FROM Session__c WHERE Experience__c\='${experienceQuery}' AND Date__c\=${date}
    [Return]                    ${sessionQuery}
Calculate Overbooked Value
    [Documentation]             Calculates an overbooked value by adding 2 to available slots and converting to integer
    ...                         This keyword takes session query results, extracts the Available_Slots__c value
    ...                         from the first record, adds 2 to it, and returns the result as an integer.
    ...
    ...                         Arguments:
    ...                         - sessionQuery: The query results from Session__c query containing records with Available_Slots__c
    ...
    ...                         Returns:
    ...                         - Integer value representing the overbooked amount (Available_Slots__c + 2)
    ...
    ...                         Example:
    ...                         ${sessionResults}=          Query Session Record By Experience And Date             ${experience}               2024-01-15
    ...                         ${overbooked}=              Calculate Overbooked Value                              ${sessionResults}
    [Arguments]                 ${sessionQuery}
    ${overBooked_float}=        Evaluate                    ${sessionQuery}+2
    ${overBooked}=              Convert To Integer          ${overBooked_float}
    [Return]                    ${overBooked}



Query Contact Record
    [Documentation]             Queries Contact records by email address
    ...                         This keyword executes a SOQL query to retrieve Contact records
    ...                         matching the provided email address, returning id, email, and Membership_Number__c.
    ...
    ...                         Arguments:
    ...                         - email: The email address of the Contact record to query
    ...
    ...                         Returns:
    ...                         - Query results containing id, email, and Membership_Number__c
    ...
    ...                         Example:
    ...                         ${contactResults}=          Query Contact Record By Email                           john.doe@example.com
    [Arguments]                 ${email}
    ${contactQuery}=            QueryRecords                SELECT id, email, Membership_Number__c FROM Contact WHERE email\='${email}'
    [Return]                    ${contactQuery}

NavigateToBooking 
    [Documentation]             Queries Booking__c records and returns the booking ID
    ...                         This keyword executes a SOQL query to find a booking record
    ...                         matching the provided date, contact query results, and experience name,
    ...                         then returns just the Salesforce ID of the booking.
    ...
    ...                         Arguments:
    ...                         - date: The date to filter bookings (Salesforce date format)
    ...                         - contactQuery: The query results from Contact query containing records
    ...                         - experienceName: The name of the experience to match
    ...
    ...                         Returns:
    ...                         - String containing the Salesforce ID of the Booking record
    ...
    ...                         Example:
    ...                         ${contactResults}=          Query Contact Record By Email                           customer@example.com
    ...                         ${bookingId}=               Get Booking ID By Date Contact And Experience           2024-01-15                  ${contactResults}    Adventure Tour
    [Arguments]                 ${date}                     ${experienceName}
    ${bookingQuery}=            QueryRecords                SELECT id, Number_of_Guests__c FROM Booking__c WHERE Date__c\=${date} AND Contact__c\='003Hu00003oTYncIAG' AND Experience_Name__c\='${experienceName}'
    GoTo                 https://co1735825376471.lightning.force.com/${bookingQuery}[records][0][Id]

NavigateToSession
    [Documentation]             Queries Session__c records after an operation to check updated availability
    ...                         This keyword executes a SOQL query to retrieve Session records
    ...                         for verification purposes after booking or other operations have been performed.
    ...
    ...                         Arguments:
    ...                         - experienceQuery: The query results from Experience__c query containing records
    ...                         - date: The date to filter sessions (should be in proper Salesforce date format)
    ...
    ...                         Returns:
    ...                         - Query results containing id and Available_Slots__c for verification
    ...
    ...                         Example:
    ...                         ${experienceResults}=       Query Experience Record     My Experience
    ...                         ${sessionAfter}=            Query Session Record After Operation                    ${experienceResults}        2024-01-15
    [Arguments]                 ${date}
    ${sessionAfter}=            QueryRecords                SELECT id, Available_Slots__c FROM Session__c WHERE Experience__c\='a09Hu00001n2mRYIAY' AND Date__c\=${date}
     GoTo                 https://co1735825376471.lightning.force.com/${sessionAfter}[records][0][Id]

FirstPrompt
    [Arguments]                 ${prompt}
    ${af_reply}=                Send Prompt                 ${prompt}
    ${similarity}=              VerifyTextSimilarity        ${af_reply}                 Could you please provide your email address and membership number so I can look up your details and provide you with the most accurate information?    threshold=0.25
    Log To Console              Similarity score: ${similarity}
    ${hallucination}=           Verify Hallucination        ${prompt}                   ${af_reply}                 Could you please provide your email address and membership number so I can look up your details and provide you with the most accurate information?    threshold=1
    Log To Console              Hallucination score: ${hallucination}
    # VerifyResponseRelevance     ${prompt}                   ${af_reply}                 threshold=0.25
    # VerifyResponseHelpfulness                               ${prompt}                   ${af_reply}                 threshold=0.25
SecondPrompt
    [Arguments]                 ${prompt}
    ${af_reply}=                Send Prompt                 ${prompt}
    VerifyTextSimilarity        ${af_reply}                 The "Underground Cave Exploration" is an exciting adventure where you can uncover the mysteries of subterranean caves guided by expert speleologists. It is categorized as an adventure activity with a medium activity level, making it suitable for those who enjoy a bit of a challenge.    threshold=0.25
    Verify Hallucination        ${prompt}                   ${af_reply}                 The "Underground Cave Exploration" is an exciting adventure where you can uncover the mysteries of subterranean caves guided by expert speleologists. It is categorized as an adventure activity with a medium activity level, making it suitable for those who enjoy a bit of a challenge.    threshold=1
    # VerifyResponseRelevance     ${prompt}                   ${af_reply}                 threshold=0.25
    # VerifyResponseHelpfulness                               ${prompt}                   ${af_reply}                 threshold=0.25
ThirdPrompt
    [Arguments]                 ${prompt}
    ${af_reply}=                Send Prompt                 ${prompt}
    VerifyTextSimilarity        ${af_reply}                 It looks like there is one available session for the Underground Cave Exploration on 2025-07-02:- **Time:** 00:00 - 05:00- **Available Slots:** 25 Unfortunately, there are only 25 slots available, but you need 27. Would you like to proceed with booking 25 guests, or would you like to choose a different date or experience?    threshold=0.25
    Verify Hallucination        ${prompt}                   ${af_reply}                 It looks like there is one available session for the Underground Cave Exploration on 2025-07-02:- **Time:** 00:00 - 05:00- **Available Slots:** 25 Unfortunately, there are only 25 slots available, but you need 27. Would you like to proceed with booking 25 guests, or would you like to choose a different date or experience?    threshold=1
    VerifyResponseRelevance     ${prompt}                   ${af_reply}                 threshold=0.25
    VerifyResponseHelpfulness                               ${prompt}                   ${af_reply}                 threshold=0.25
FourthPrompt
    [Arguments]                 ${prompt}
    ${af_reply}=                Send Prompt                 ${prompt}
    VerifyTextSimilarity        ${af_reply}                 Your booking for the Underground Cave Exploration on 2025-07-02 for 2 guests has been successfully created!    threshold=0.25
    Verify Hallucination        ${prompt}                   ${af_reply}                 Your booking for the Underground Cave Exploration on 2025-07-02 for 2 guests has been successfully created!    threshold=1
    VerifyResponseRelevance     ${prompt}                   ${af_reply}                 threshold=0.25
    VerifyResponseHelpfulness                               ${prompt}                   ${af_reply}                 threshold=0.25
