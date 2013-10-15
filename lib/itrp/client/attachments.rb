module Itrp
  class Attachments

    AWS_PROVIDER = 'aws'
    FILENAME_TEMPLATE = '${filename}'

    def initialize(client)
      @client = client
    end

    # upload the attachments in :attachments to ITRP and return the data with the uploaded attachment info
    def upload_attachments!(path, data)
      raise_exceptions = !!data.delete(:attachments_exception)
      attachments = [data.delete(:attachments)].flatten.compact
      return if attachments.empty?

      # retrieve the upload configuration for this record from ITRP
      storage = @client.get(path =~ /\d+$/ ? path : "#{path}/new", {attachment_upload_token: true}, @client.send(:expand_header))[:storage_upload]
      report_error("Attachments not allowed for #{path}", raise_exceptions) and return unless storage

      # upload each attachment and store the {key, filesize} has in the note_attachments parameter
      data[:note_attachments] = attachments.map {|attachment| upload_attachment(storage, attachment, raise_exceptions) }.compact.to_json
    end

    private

    def report_error(message, raise_exceptions)
      if raise_exceptions
        raise Itrp::UploadFailed.new(message)
      else
        @client.logger.error{ message }
      end
    end

    # upload a single attachment and return the data for the note_attachments
    # returns nil and provides an error in case the attachment upload failed
    def upload_attachment(storage, attachment, raise_exceptions)
      begin
        # attachment is already a file or we need to open the file from disk
        unless attachment.respond_to?(:path) && attachment.respond_to?(:read)
          raise "file does not exist: #{attachment}" unless File.exists?(attachment)
          attachment = File.open(attachment, 'r')
        end

        # there are two different upload methods: AWS S3 and ITRP local storage
        key_template = "#{storage[:upload_path]}#{FILENAME_TEMPLATE}"
        key = key_template.gsub(FILENAME_TEMPLATE, File.basename(attachment.path))
        upload_method = storage[:provider] == AWS_PROVIDER ? :aws_upload : :itrp_upload
        send(upload_method, storage, key_template, key, attachment)

        # return the values for the note_attachments param
        {key: key, filesize: File.size(attachment.path)}
      rescue ::Exception => e
        report_error("Attachment upload failed: #{e.message}", raise_exceptions)
        nil
      end
    end

    def aws_upload(aws, key_template, key, attachment)
      # upload the file to AWS
      response = send_file(aws[:upload_uri], {
        key: key_template,
        AWSAccessKeyId: aws[:access_key],
        acl: 'private',
        signature: aws[:signature],
        success_action_redirect: aws[:success_url],
        policy: aws[:policy],
        file: attachment # file must be last (will that work in Ruby 1.9.3)?
      })
      # this is a bit of a hack, but Amazon S3 returns only XML :(
      xml = response.raw.body || ''
      error = xml[/<Error>.*<Message>(.*)<\/Message>.*<\/Error>/, 1]
      raise "AWS upload to #{aws[:upload_uri]} for #{key} failed: #{error}" if error

      # inform ITRP of the successful upload
      response = @client.get(aws[:success_url].split('/').last, {key: key}, @client.send(:expand_header))
      raise "ITRP confirmation #{aws[:success_url].split('/').last} for #{key} failed: #{response.message}" unless response.valid?
    end

    # upload the file directly to ITRP
    def itrp_upload(itrp, key_template, key, attachment)
      response = send_file(itrp[:upload_uri], {
        file: attachment,
        key: key_template
      })
      raise "ITRP upload to #{itrp[:upload_uri]} for #{key} failed: #{response.message}" unless response.valid?
    end

    def send_file(uri, params)
      params = {:'Content-Type' => MIME::Types.type_for(params[:key])[0] || MIME::Types["application/octet-stream"][0]}.merge(params)
      data, header = Itrp::Multipart::Post.prepare_query(params)
      ssl, domain, port, path = @client.send(:ssl_domain_port_path, uri)
      request = Net::HTTP::Post.new(path, header)
      request.body = data
      @client.send(:_send, request, domain, port, ssl)
    end

  end
end