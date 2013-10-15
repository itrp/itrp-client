require 'spec_helper'

describe Itrp::Attachments do

  before(:each) do
    @client = Itrp::Client.new(api_token: 'secret', max_retry_time: -1)
    @attachments = Itrp::Attachments.new(@client)
  end

  context 'upload_attachments!' do
    it 'should not do anything when no :attachments are present' do
      @attachments.upload_attachments!('/requests', {status: :in_progress}).should == nil
    end

    it 'should not do anything when :attachments is nil' do
      @attachments.upload_attachments!('/requests', {attachments: nil}).should == nil
    end

    it 'should not do anything when :attachments is empty' do
      @attachments.upload_attachments!('/requests', {attachments: []}).should == nil
      @attachments.upload_attachments!('/requests', {attachments: [nil]}).should == nil
    end

    it 'should show a error if no attachment may be uploaded' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/sites/1?attachment_upload_token=true').to_return(body: {name: 'site 1'}.to_json)
      expect_log('Attachments not allowed for /sites/1', :error)
      @attachments.upload_attachments!('/sites/1', {attachments: ['file1.png']}).should == nil
    end

    it 'should raise an exception if no attachment may be uploaded' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/sites/1?attachment_upload_token=true').to_return(body: {name: 'site 1'}.to_json)
      message = 'Attachments not allowed for /sites/1'
      expect{ @attachments.upload_attachments!('/sites/1', {attachments: ['file1.png'], attachments_exception: true}) }.to raise_error(::Itrp::UploadFailed, message)
    end

    it 'should add /new to the path for new records' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/sites/new?attachment_upload_token=true').to_return(body: {missing: 'storage'}.to_json)
      expect_log('Attachments not allowed for /sites', :error)
      @attachments.upload_attachments!('/sites', {attachments: ['file1.png']}).should == nil
    end

    it 'should replace :attachments with :note_attachments after upload' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/requests/new?attachment_upload_token=true').to_return(body: {storage_upload: 'conf'}.to_json)
      expect(@attachments).to receive(:upload_attachment).with('conf', 'file1.png', false).ordered{ 'uploaded file1.png' }
      expect(@attachments).to receive(:upload_attachment).with('conf', 'file2.zip', false).ordered{ 'uploaded file2.zip' }
      data = {leave: 'me alone', attachments: %w(file1.png file2.zip)}
      @attachments.upload_attachments!('/requests', data)
      data[:attachments].should == nil
      data[:leave].should == 'me alone'
      data[:note_attachments].should == ['uploaded file1.png', 'uploaded file2.zip'].to_json
    end

    it 'should set raise_exception flag to true when :attachments_exception is set' do
      stub_request(:get, 'https://secret:@api.itrp.com/v1/requests/new?attachment_upload_token=true').to_return(body: {storage_upload: 'conf'}.to_json)
      expect(@attachments).to receive(:upload_attachment).with('conf', 'file1.png', true).ordered{ 'uploaded file1.png' }
      data = {leave: 'me alone', attachments: 'file1.png', attachments_exception: true}
      @attachments.upload_attachments!('/requests', data)
      data[:attachments].should == nil
      data[:attachments_exception].should == nil
      data[:leave].should == 'me alone'
      data[:note_attachments].should == ['uploaded file1.png'].to_json
    end
  end

  context 'upload_attachment' do

    it 'should log an exception when the file could not be found' do
      expect_log('Attachment upload failed: file does not exist: unknown_file', :error)
      @attachments.send(:upload_attachment, nil, 'unknown_file', false).should == nil
    end

    it 'should raise an exception when the file could not be found' do
      message = 'Attachment upload failed: file does not exist: unknown_file'
      expect{ @attachments.send(:upload_attachment, nil, 'unknown_file', true) }.to raise_error(::Itrp::UploadFailed, message)
    end

    context 'aws' do
      before(:each) do
        @aws_conf = {
            provider: 'aws',
            upload_uri: 'https://itrp.s3.amazonaws.com/',
            access_key: "AKIA6RYQ",
            success_url: "https://mycompany.itrp.com/s3_success?sig=99e82e8a046",
            policy: "eydlgIH0=",
            signature: 'nbhdec4k=',
            upload_path: 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/'
        }
        @key_template = 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}'
        @key = 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/upload.txt'

        @multi_part_body = "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"Content-Type\"\r\n\r\napplication/octet-stream\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\nattachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"AWSAccessKeyId\"\r\n\r\nAKIA6RYQ\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"acl\"\r\n\r\nprivate\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"signature\"\r\n\r\nnbhdec4k=\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"success_action_redirect\"\r\n\r\nhttps://mycompany.itrp.com/s3_success?sig=99e82e8a046\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"policy\"\r\n\r\neydlgIH0=\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{@fixture_dir}/upload.txt\"\r\nContent-Type: text/plain\r\n\r\ncontent\r\n--0123456789ABLEWASIEREISAWELBA9876543210--"
        @multi_part_headers = {'Accept'=>'*/*', 'Content-Type'=>'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210', 'User-Agent'=>'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6'}
      end

      it 'should open a file from disk' do
        expect(@attachments).to receive(:aws_upload).with(@aws_conf, @key_template, @key, kind_of(File))
        @attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", false).should == {key: @key, filesize: 7}
      end

      it 'should sent the upload to AWS' do
        stub_request(:post, 'https://itrp.s3.amazonaws.com/').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: 'OK', status: 303, headers: {'Location' => 'https://mycompany.itrp.com/s3_success?sig=99e82e8a046'})
        stub_request(:get, "https://secret:@api.itrp.com/v1/s3_success?sig=99e82e8a046&key=#{@key}").to_return(body: {}.to_json)
        @attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", false).should == {key: @key, filesize: 7}
      end

      it 'should report an error when AWS upload fails' do
        stub_request(:post, 'https://itrp.s3.amazonaws.com/').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: %(<?xml version="1.0" encoding="UTF-8"?>\n<Error><Code>AccessDenied</Code><Message>Invalid according to Policy</Message><RequestId>1FECC4B719E426B1</RequestId><HostId>15+14lXt+HlF</HostId></Error>), status: 303, headers: {'Location' => 'https://mycompany.itrp.com/s3_success?sig=99e82e8a046'})
        expect_log("Attachment upload failed: AWS upload to https://itrp.s3.amazonaws.com/ for #{@key} failed: Invalid according to Policy", :error)
        @attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", false).should == nil
      end

      it 'should report an error when ITRP confirmation fails' do
        stub_request(:post, 'https://itrp.s3.amazonaws.com/').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: 'OK', status: 303, headers: {'Location' => 'https://mycompany.itrp.com/s3_success?sig=99e82e8a046'})
        stub_request(:get, "https://secret:@api.itrp.com/v1/s3_success?sig=99e82e8a046&key=#{@key}").to_return(body: {message: 'oops!'}.to_json)
        expect_log('Request failed: oops!', :error)
        expect_log("Attachment upload failed: ITRP confirmation s3_success?sig=99e82e8a046 for #{@key} failed: oops!", :error)
        @attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", false).should == nil
      end

      it 'should raise an exception when AWS upload fails' do
        stub_request(:post, 'https://itrp.s3.amazonaws.com/').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: %(<?xml version="1.0" encoding="UTF-8"?>\n<Error><Code>AccessDenied</Code><Message>Invalid according to Policy</Message><RequestId>1FECC4B719E426B1</RequestId><HostId>15+14lXt+HlF</HostId></Error>), status: 303, headers: {'Location' => 'https://mycompany.itrp.com/s3_success?sig=99e82e8a046'})
        message = "Attachment upload failed: AWS upload to https://itrp.s3.amazonaws.com/ for #{@key} failed: Invalid according to Policy"
        expect{ @attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", true) }.to raise_error(::Itrp::UploadFailed, message)
      end
    end

    context 'itrp' do
      before(:each) do
        @itrp_conf = {
            provider: 'local',
            upload_uri: 'https://api.itrp.com/attachments',
            upload_path: 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/'
        }
        @key_template = 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}'
        @key = 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/upload.txt'

        @multi_part_body = "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"Content-Type\"\r\n\r\napplication/octet-stream\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"/home/mathijs/dev/itrp-client/spec/support/fixtures/upload.txt\"\r\nContent-Type: text/plain\r\n\r\ncontent\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\nattachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}\r\n--0123456789ABLEWASIEREISAWELBA9876543210--"
        @multi_part_headers = {'Accept'=>'*/*', 'Content-Type'=>'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210', 'User-Agent'=>'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6'}
      end

      it 'should open a file from disk' do
        expect(@attachments).to receive(:itrp_upload).with(@itrp_conf, @key_template, @key, kind_of(File))
        @attachments.send(:upload_attachment, @itrp_conf, "#{@fixture_dir}/upload.txt", false).should == {key: @key, filesize: 7}
      end

      it 'should sent the upload to ITRP' do
        stub_request(:post, 'https://api.itrp.com/attachments').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {}.to_json)
        @attachments.send(:upload_attachment, @itrp_conf, "#{@fixture_dir}/upload.txt", false).should == {key: @key, filesize: 7}
      end

      it 'should report an error when ITRP upload fails' do
        stub_request(:post, 'https://api.itrp.com/attachments').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {message: 'oops!'}.to_json)
        expect_log('Request failed: oops!', :error)
        expect_log("Attachment upload failed: ITRP upload to https://api.itrp.com/attachments for #{@key} failed: oops!", :error)
        @attachments.send(:upload_attachment, @itrp_conf, "#{@fixture_dir}/upload.txt", false).should == nil
      end

      it 'should raise an exception when ITRP upload fails' do
        stub_request(:post, 'https://api.itrp.com/attachments').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {message: 'oops!'}.to_json)
        expect_log('Request failed: oops!', :error)
        message = "Attachment upload failed: ITRP upload to https://api.itrp.com/attachments for #{@key} failed: oops!"
        expect{ @attachments.send(:upload_attachment, @itrp_conf, "#{@fixture_dir}/upload.txt", true) }.to raise_error(::Itrp::UploadFailed, message)
      end
    end

  end
end