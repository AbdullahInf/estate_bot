module Google
  class DriveService
    BASE_URL = "https://www.googleapis.com/drive/v3"

    GOOGLE_DOC_MIME_TYPES = %w[
      application/vnd.google-apps.document
      application/vnd.google-apps.spreadsheet
      application/vnd.google-apps.presentation
    ].freeze

    EXPORT_FORMATS = {
      "application/vnd.google-apps.document"     => "application/pdf",
      "application/vnd.google-apps.spreadsheet"  => "application/pdf",
      "application/vnd.google-apps.presentation" => "application/pdf"
    }.freeze

    def initialize(access_token)
      @access_token = access_token
    end

    def search_files(query:, max_results: 10)
      resp = get("files",
        q:         query,
        pageSize:  max_results,
        fields:    "files(id,name,mimeType,size,modifiedTime,webViewLink)"
      )
      resp["files"] || []
    end

    # Returns { data: <binary string>, mime_type: <string>, filename: <string> }
    def download_file(file_id:, file_name:, mime_type:)
      if GOOGLE_DOC_MIME_TYPES.include?(mime_type)
        export_mime = EXPORT_FORMATS[mime_type]
        data = export_file(file_id, export_mime)
        { data: data, mime_type: export_mime, filename: "#{File.basename(file_name, '.*')}.pdf" }
      else
        data = download_binary(file_id)
        { data: data, mime_type: mime_type, filename: file_name }
      end
    end

    private

    def export_file(file_id, export_mime_type)
      response = Faraday.get("#{BASE_URL}/files/#{file_id}/export") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
        req.params["mimeType"] = export_mime_type
      end
      response.body
    end

    def download_binary(file_id)
      response = Faraday.get("#{BASE_URL}/files/#{file_id}") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
        req.params["alt"] = "media"
      end
      response.body
    end

    def get(path, params = {})
      response = Faraday.get("#{BASE_URL}/#{path}") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
        req.params.merge!(params)
      end
      JSON.parse(response.body)
    end
  end
end
