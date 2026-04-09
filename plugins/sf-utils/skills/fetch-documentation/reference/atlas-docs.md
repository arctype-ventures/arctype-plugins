# Atlas Documentation (API References)

**URL pattern:** `developer.salesforce.com/docs/atlas.en-us.{docset}...`

## Procedure

Atlas pages load content via JavaScript. Use the content API instead of fetching HTML directly.

**API endpoint:**
```
https://developer.salesforce.com/docs/get_document_content/{short_name}/{page}/en-us/260.0
```

### URL Translation

1. Extract `short_name`: text between `atlas.en-us.` and `.meta` (e.g., `api_meta`)
2. Extract `page`: the `.htm` filename (e.g., `metadata.htm`)
3. Build: `get_document_content/{short_name}/{page}/en-us/260.0`

Fetch the translated API URL with WebFetch or curl.

### Response format

JSON with structure:

```json
{
  "id": "page_id",
  "title": "Page Title",
  "content": "<HTML documentation content>"
}
```

## Examples

| Original URL                                               | API URL                                                            |
| ---------------------------------------------------------- | ------------------------------------------------------------------ |
| /docs/atlas.en-us.api_meta.meta/api_meta/metadata.htm      | /docs/get_document_content/api_meta/metadata.htm/en-us/260.0       |
| /docs/atlas.en-us.api_rest.api/api_rest/resources_list.htm | /docs/get_document_content/api_rest/resources_list.htm/en-us/260.0 |
| /docs/atlas.en-us.apexcode.meta/apexcode/apex_classes.htm  | /docs/get_document_content/apexcode/apex_classes.htm/en-us/260.0   |
