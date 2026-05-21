*** Settings ***
Library                         QForce
Library                         QWeb
Library                         String
Library                         DateTime
Library                         Collections


*** Variables ***
${BROWSER}                      chrome
${homeUrl}                     ${loginUrl}/lightning/page/home



*** Keywords ***
Setup Browser
    Set Library Search Order    QWeb
    Evaluate                    random.seed()
    Open Browser                about:blank                 ${BROWSER}    
    SetConfig                   LineBreak                   ${EMPTY}                    #\ue000
    SetConfig                   DefaultTimeout              20s                         #sometimes salesforce is slow
    SetConfig                   CaseInsensitive             True

End suite
    Close All Browsers

Login
    [Documentation]             Login to Salesforce instance
    GoTo                        ${loginUrl}
    TypeText                    Username                    ${username}
    TypeText                    Password                    ${password}
    ClickText                   Log In
    ${isMFA}=                   IsText                      Verify Your Identity        #Determines MFA is prompted
    Log To Console              ${isMFA}
    IF                          ${isMFA}                    #Conditional Statement for if MFA verification is required to proceed
         ${mfa_code}=            GetOTP                      ${username}                 ${MY_SECRET}                ${password}
         TypeSecret              Code                        ${mfa_code}
         ClickText               Verify
    END

Setup       
    GoTo                        ${login_url}lightning/setup/SetupOneHome/home

Home
    [Documentation]             Navigate to homepage, login if needed
    GoTo                        ${homeUrl}
    Sleep                       3
    ${login_status}=            IsText                      To access this page, you have to log in to Salesforce.                 2
    Run Keyword If              ${login_status}             Login
    VerifyText                  Home

InsertRandomValue
    [Documentation]             This keyword accepts a character count, suffix, and prefix.
    ...                         It then types a random string into the given field.
    ...                         This is an example of generating dynamic data within a test
    ...                         and how to create a keyword with optional/default arguments.
    [Arguments]                 ${field}                    ${charCount}=5              ${prefix}=                  ${suffix}=
    Set Library Search Order    QWeb
    ${testRandom}=              Generate Random String      ${charCount}
    TypeText                    ${field}                    ${prefix}${testRandom}${suffix}


MFA Login
    ${isMFA}=                   IsText                      Verify Your Identity        #Determines MFA is prompted
    Log To Console              ${isMFA}
    IF                          ${isMFA}                    #Conditional Statement for if MFA verification is required to proceed
        ${mfa_code}=            GetOTP                      ${username}                 ${MY_SECRET}                ${password}
        TypeSecret              Code                        ${mfa_code}
        ClickText               Verify
    END

#TODO: Add Login As
Login As
    [Documentation]             Login As different persona. User needs to be logged into Salesforce with Admin rights
    ...                         before calling this keyword to change persona.
    ...                         Example:
    ...                         LoginAs                     Chatter Expert
    [Arguments]                 ${persona}
    ClickText                   Setup
    ClickItem                   Setup                       delay=1
    SwitchWindow                NEW
    TypeText                    Search Setup                ${persona}                  delay=2
    ClickElement                //*[@title\="${persona}"]                               delay=2                     # wait for list to populate, then click
    VerifyText                  Freeze                      timeout=45                  # this is slow, needs longer timeout
    ClickText                   Login                       anchor=Freeze               partial_match=False         delay=1

Configure Product Bundles
    [Documentation]    Selects bundles from pipe-delimited list (e.g., "Bundle A|Bundle B|Bundle C")
    [Arguments]    ${bundles}
    
    @{bundle_list}=    Split String    ${bundles}    |
    FOR    ${bundle}    IN    @{bundle_list}
        ${bundle_trimmed}=    Strip String    ${bundle}
        ClickItem    checkbox    anchor=${bundle_trimmed}    tag=paper-checkbox
    END
