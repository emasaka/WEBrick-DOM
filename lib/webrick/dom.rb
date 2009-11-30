require 'webrick'
require 'nokogiri'

module WEBrick
  module HTTPServlet
    class FileHandlerWithXPath < DefaultFileHandler
      def do_GET(req, res)
        if req['x-path']
          make_xpath_content(req, res, @local_path, req['x-path'])
          raise HTTPStatus::PartialContent # 206 Partial Content
        else
          super
        end
      end

      def make_xpath_content(req, res, filename, xpath)
        mtype = HTTPUtils::mime_type(filename, @config[:MimeTypes])
        begin
          open(filename) do |io|
            doc = Nokogiri::HTML(io)
            header = doc.xpath('//head')
            nodes = doc.xpath(xpath)
            raise HTTPStatus::RequestRangeNotSatisfiable if nodes.empty?
            body = ['<html>',
                    (header.to_html unless header.empty?),
                    '<body>', nodes.to_html, '</body></html>' ].join
            res['content-type'] = mtype
            res['content-length'] = str_bytesize(body)
            res.body = body
          end
        rescue Nokogiri::XML::XPath::SyntaxError
          raise HTTPStatus::BadRequest, "Unrecognized XPath: #{xpath}"
        end
      end

      if String.public_method_defined?(:bytesize)
        def str_bytesize(str); str.bytesize; end # Ruby 1.9
      else
        def str_bytesize(str); str.size; end # Ruby 1.8
      end

    end                         # class FileHandlerWithXPath

    FileHandler.add_handler('html', FileHandlerWithXPath)
    FileHandler.add_handler('htm', FileHandlerWithXPath)

  end
end

# webrick/dom: Wraps WEBrick to support X-Path: request header.
#
# Example:
#
# require 'webrick/dom'
#
# srv = WEBrick::HTTPServer.new({ :DocumentRoot => './',
#                                 :BindAddress => '127.0.0.1',
#                                 :Port => 20080 })
# trap('INT'){ srv.shutdown }
# srv.start
