*** Settings ***
Library                         QForce
Resource                        ../Resources/common.robot
Suite Setup                     Setup Browser
Suite Teardown                  End suite

*** Test Cases ***

AgentforceSimple
    #Data Setup
    ${date}=                    Get Current Date            result_format=%Y-%m-%d
    ${session_id}=              Manage Session Records      ${date}
    GoTo                        ${ExperienceUrl}

    # Agent Interactions - Initial Inquiry
    # Agent Interactions - Initial Inquiry
    ${firstAgentReply}          Send Prompt                 What can you tell me about the underground cave exploration?
    VerifyTextSimilarity        ${firstAgentReply}          Could you please provide your email address and membership number so I can look up your details and provide you with the most accurate information?    threshold=0.5

    # Agent Interactions - Provide Credentials
    ${secondAgentReply}         Send Prompt                 My email address is sofiarodriguez@example.com and my membership number is 10008155
    VerifyResponseSimilarity    ${secondAgentReply}         The "Underground Cave Exploration" is an exciting adventure where you can uncover the mysteries of subterranean caves guided by expert speleologists. It is categorized as an adventure activity with a medium activity level, making it suitable for those who enjoy a bit of a challenge.    threshold=0.5

    # Agent Interactions - Attempt to overbook
    ${thirdAgentReply}          Send Prompt                 I would like to book this experience for ${date} for 30 guests
    VerifyResponseRelevance     I would like to book this experience for ${date} for 30 guests                      ${thirdAgentReply}    threshold=0.25

    # Agent Interactions - Successful booking
    ${fourthAgentReply}         Send Prompt                 Lets book for 2 guests instead
    VerifyResponseHelpfulness                               Lets book for 2 guests instead                          ${fourthAgentReply}    threshold=0.25

    #Salesforce Validations
    JwtLogin
    NavigateToBooking         ${date}                     Underground Cave Exploration
    VerifyField                 Number of Guests            2
    VerifyField                 Contact                     Sofia Rodriguez             tag=a
    VerifyField                 Experience Name             Underground Cave Exploration                            partial_match=True
    VerifyField                 Status                      Confirmed

    NavigateToSession         ${date}
    VerifyField                 Experience                  Underground Cave Exploration                            tag=a                 partial_match=True
    VerifyField                 Booked Slots                2

