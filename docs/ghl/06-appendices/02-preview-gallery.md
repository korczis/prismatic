+++
title = "Preview Gallery for GHL"
description = "Visual previews linked to each section of the General Honest License (GHL)."
template = "ghl.html"
draft = false
+++

# Preview Gallery

{% for page in section.pages %}
- [{{ page.title }}]({{ page.permalink }})
  {% if page.extra.preview_image %}
  ![Preview]({{ page.extra.preview_image }})
  {% endif %}
{% endfor %}
