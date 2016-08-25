# Document Store API

The purpose of this document is to outline the two versions of the Document Store API.

## Version 1

The initial version of the API is handled by the documents controller and exposes the following interface for use by the views as a GUI:

- GET /documents - displays a list of documents assigned to the owner that have the main codap document attribute set
- GET /documents/:id - displays the content and metadata about a document
- GET /documents/new - displays a form to create a new document
- GET /documents/:id/edit - displays a form to edit an existing document
- POST /documents - creates a new document
- PATCH/PUT /documents/:id - updates an existing document
- DELETE /documents/:id - deletes an existing document

And a CODAP specific API that was also used for the initial version of the [Cloud File Manager](https://github.com/concord-consortium/cloud-file-manager) that is called via AJAX requests:

- GET /document/all - returns a json array of documents assigned to the owner with the main codap document attribute set.  The format of the returned data is:  ```[{"name": <name>, "id": <id>, _permissions: (1|0)}, ...]``` where ```_permissions: 1``` means the document is shared.

- GET /document/open - returns the content of the document specified by a varying set of query parameters.  The first set is a combination of the recordname or doc parameter that is used as a title lookup combined with the owner's user id.  Those two attributes are then used to lookup the document first with the runKey parameter and then without it if no document is found.  If no recordname or doc parameter is present the recordid parameter is used.  If the user is authorized to open the document but is not the owner then a second document with the same title and runKey but with the current user as the owner is either found or created.  The format of the returned data is the contents of the file with three extra HTTP headers: ```Document-Id, X-Codap-Opened-From-Shared-Document and X-Codap-Will-Overwrite```

- GET /document/save - saves the document specified either by recordid or a combination of title and runKey.  If the document is found but the user is not the owner and is authorized to save then a new document is created using the same title and runKey if it has not already been created.  Along with the document content the shared and parent_id attributes are set on the document if present in the query parameters.

- GET /document/patch - updates a document specified by recordid using the JSON Patch specification.  Along with patching the contents the shared and parent_id attributes are also set if present in the query parameters.

- GET /document/rename - renames a document specified in the same manner as the open request.

- GET /document/delete - deletes a document specified in the same manner as the open request.

- GET /document/launch - renders a launch button for a document specified in the same manner as the open request.

- GET /document/report - renders a launch button for the report view for a document specified in the same manner as the open request.

## Version 2

The second version of the API is handled by the documents_v2 controller and exposes only a non-GUI programmatic API in the /v2/ namespace as:

- GET /v2/documents/:id - returns the contents of a document specified by id.  This requires either the document's read-only or read-write access keys.

- PUT /v2/documents/:id - updates the contents of a document specified by id.  This requires the document's read-write access keys.

- PATCH /v2/documents/:id - updates the contents of a document specified by id using the JSON Patch specification.  This requires the document's read-write access keys.

- POST /v2/documents - creates a copy of a document identified by the source query parameter and returns the new id of the document along with its read-only and read-write access keys.  The source document must be a shared document or else the copy with fail.  No access key is needed.

### Version 2 Access keys

The version 2 API uses 20 hex character read-only keys and 40 hex character read-write keys to enable operations on the specified document.  The two keys are denoted in the query parameters with either a ```RO::``` or ```RW::``` prefix under the same accessKey query parameter.  Existing runKeys generated by the Cloud File Manager were copied to the documents read-write accessKey as part of the migration in the V2 update.  This allows existing documents to be accessed via the V2 API.