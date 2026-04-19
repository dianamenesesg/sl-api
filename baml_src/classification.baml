class Theme {
  title string
  description string
}

class ClassificationResult {
  model_reasoning string @description("Step-by-step reasoning explaining why this theme was chosen")
  chosen_theme_title string @description("The title of the theme that best matches the input text. Must match exactly one of the provided theme titles.")
}

function ClassifyText(text: string, themes: Theme[]) -> ClassificationResult {
  client ClassificationClient
  prompt #"
    {{ _.role("system") }}
    You are a text classification assistant. Your task is to classify the given text
    into exactly one of the provided themes. Analyze the text carefully, choose the
    most appropriate theme, and explain your reasoning.

    Available themes:
    {% for theme in themes %}
    - Title: {{ theme.title }}
      Description: {{ theme.description }}
    {% endfor %}

    {{ ctx.output_format }}

    {{ _.role("user") }}
    Classify the following text:
    {{ text }}
  "#
}
test TestClassifyTechnical {
  functions [ClassifyText]
  args {
    text "I am calling because I have a problem with my internet connection"
    themes [
        {
            "title": "Technical support",
            "description": "The customer is calling for technical support"
        },
        {
            "title": "Billing",
            "description": "The customer is calling for billing issues"
        },
        {
            "title": "Refund",
            "description": "The customer is calling for a refund"
        }
    ]
  }
}

test TestClassifyRefund {
  functions [ClassifyText]
  args {
    text "I was charged twice for my subscription last month and need a refund."
    themes [
        {
            "title": "Technical support",
            "description": "The customer is calling for technical support"
        },
        {
            "title": "Billing",
            "description": "The customer is calling for billing issues"
        },
        {
            "title": "Refund",
            "description": "The customer is calling for a refund"
        }
    ]
  }
}