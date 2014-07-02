require 'fileutils'
require 'erb'
require 'ostruct'
require 'cgi'
require 'redcarpet'

module Playground
  class Generator
    def generate(input, output)
      @input = input
      @output = output

      # Remove anything already there
      FileUtils.rm_rf(@output)

      # Make folders
      @doc_dir = @output + '/Documentation'
      FileUtils.mkdir_p(@doc_dir)

      # Copy stylesheet
      @data_dir = File.expand_path('../data', __FILE__)
      FileUtils.cp(@data_dir + '/style.css', @doc_dir)

      # Setup
      section = 1
      @contents_sections = []
      html = ''

      # Parse markdown
      chunks = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(File.read(input)).split("\n\n")

      # Loop through chunks
      chunks.each do |chunk|
        # Code
        if chunk.start_with?('<pre><code>')
          if html.length > 0
            write_html(html, section)
            section += 1
          end

          swift = CGI.unescapeHTML(chunk[11, chunk.length - 11 - 13])
          write_swift(swift, section)
          section += 1
          html = ''
        # HTML
        else
          html << chunk + "\n\n"
        end
      end

      # Write any remaining HTML
      if html.length > 0
        write_html(html, section)
      end

      # Create contents
      contents = erb(@data_dir + '/contents.xcplayground.erb', { sdk: 'macosx', sections: @contents_sections.join("\n    ") })
      File.write(output + '/contents.xcplayground', contents)
    end

    # Write an HTML file to the output package and add its metadata to the contents
    def write_html(html, section)
      filename = "section-#{section.to_s.rjust(3, '0')}.html"
      @contents_sections << %Q{<documentation relative-path="#{filename}"/>}

      html = html[0, html.length - 2]
      html = erb(@data_dir + '/section.html.erb', { title: filename, content: html })
      File.write(@doc_dir + "/#{filename}", html)
    end

    # Write a Swift file to the output package and add its metadata to the contents
    def write_swift(swift, section)
      filename = "section-#{section.to_s.rjust(3, '0')}.swift"
      @contents_sections << %Q{<code source-file-name="#{filename}"/>}

      File.write(@output + "/#{filename}", swift)
    end

    private

    # Render an ERB template
    def erb(template_path, vars)
      template = File.read(template_path)
      ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
    end
  end
end
