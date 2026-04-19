enum Gender {
  Male
  Female
  Other
  Refused
}

enum ContactMethod {
  Email
  Phone
}

class PersonalInfo {
  first_name string @description("Customer's first name")
  last_name string @description("Customer's last name")
  gender Gender @description("Customer's gender: use Refused if the customer explicitly declines to answer, Other if unknown or unspecified")
  @@dynamic
}

class ContactInfo {
  email string? @description("Customer's email address, null if not provided")
  phone string? @description("Customer's phone number, null if not provided or refused")
  preferred_contact_method ContactMethod? @description("Preferred contact method, null if not mentioned")
  call_reasons string[]? @description("Reasons for the call, null if not specified")
  @@dynamic
}

class CustomerForm {
  personal_info PersonalInfo
  contact_info ContactInfo
}

function ExtractCustomerInfo(text: string) -> CustomerForm {
  client ExtractionClient
  prompt #"
    {{ _.role("system") }}
    You are a data extraction assistant. Extract structured customer information
    from the conversation provided by the user.

    Rules:
    - personal_info (first_name, last_name, gender) are required — always fill them.
    - For gender: use Refused if the customer declines to share, Other if not binary.
    - For all other fields: if not mentioned or refused, set to null.
    - Do not infer or guess values that are not explicitly stated.
    - For call_reasons, extract a list if multiple reasons are mentioned.
    - Normalize values regardless of how they are expressed: numbers may be spoken as words
      in any language (e.g. "cero sept quarante neuf" → "07 49"), spelled out in English
      ("zero seven four nine" → "0749"), or mixed formats. Convert to standard digit form.
    - Apply the same normalization to emails: "john at example dot com" → "john@example.com".

    {{ ctx.output_format }}

    {{ _.role("user") }}
    {{ text }}
  "#
}

class ComplementaryInfo {
  @@dynamic
}

class DynamicOutput {
  personal_info PersonalInfo
  contact_info ContactInfo
  complementary_info ComplementaryInfo?
}

function ExtractDynamic(text: string) -> DynamicOutput {
  client ExtractionClient
  prompt #"
    {{ _.role("system") }}
    You are a data extraction assistant. Extract structured information from the text provided by the user.

    Rules:
    - Return ONLY valid JSON, no explanation, no markdown fences, no extra text.
    - If a field is not present or the source refuses to provide it, use null for nullable fields or omit optional fields entirely.
    - Do not infer or guess values that are not explicitly stated.
    - For call_reasons, extract a list if multiple reasons are mentioned.
    - Normalize values regardless of how they are expressed: numbers may be spoken as words
      in any language (e.g. "cero sept quarante neuf" → "07 49"), spelled out in English
      ("zero seven four nine" → "0749"), or mixed formats. Convert to standard digit form.
    - Apply the same normalization to emails: "john at example dot com" → "john@example.com".


    {{ ctx.output_format }}

    {{ _.role("user") }}
    {{ text }}
  "#
}
test JohnDoe {
  functions [ExtractDynamic]
  args {
    text #"text": "Agent: Good morning! Thank you for reaching out. 
    I’ll need to collect some basic details to assist you better. 
    Could you please provide your first and last name? 
    Customer: Sure! My name is John Doe. Agent: Thank you, John. 
    May I also ask for your gender? Customer: I'd prefer not to share that at the moment.
    Agent: No problem at all. Now, for contact purposes, could you share your email address? 
    Customer: Yes, my email is johndoe@example.com. Agent: Great! 
    Do you have a phone number where we can reach you? 
    Customer: I’d rather not provide that right now. 
    Agent: That’s completely fine. How would you prefer us to contact you—by email or phone? 
    Customer: Please contact me via Email. Agent: Understood! 
    Lastly, can you share the reason for your call today? 
    Customer: I’m not ready to specify that just yet. Agent: That’s okay, John! I’ve noted everything down. 
    If you need any further assistance, feel free to reach out. Have a great day!"#
  }
}
test AllRequiredFields {
  functions [ExtractDynamic]
  args {
    text #"Customer: I'm Jane Smith, I'm non-binary. my phone is one 2 3 four cinq six sept huit. 
    my email is test at test dot com, my preferd contact method is smoke signals
    I'm calling because I'm testing this"#
  }
}
test MissingRquiredFields {
  functions [ExtractDynamic]
  args {
    text "Agent: what is your first and last name? Customer: I'm Jane Agent: great! May I also ask your gender? Customer: I don't have time for that"
  }
}
