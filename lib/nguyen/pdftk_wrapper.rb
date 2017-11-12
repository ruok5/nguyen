require 'tempfile'
module Nguyen
  class PdftkError < StandardError
  end

  # Wraps calls to PdfTk
  class PdftkWrapper

    attr_reader :pdftk, :options

    # PdftkWrapper.new('/usr/bin/pdftk', :flatten => true, :encrypt => true, :encrypt_options => 'allow Printing')
    def initialize(pdftk_path, options = {})
      @pdftk = pdftk_path
      @options = options
    end

    # pdftk.fill_form '/path/to/form.pdf', '/path/to/destination.pdf', xfdf_or_fdf_object
    def fill_form(template, destination, form_data_format)
      tmp = Tempfile.new('pdf_forms-fdf')
      tmp.close
      if (form_data_format.instance_of? String
        # just save the string to file
        File.write(tmp, form_data_format)
      else
        form_data_format.save_to tmp.path
      end
      command = pdftk_command %Q("#{template}"), 'fill_form', %Q("#{tmp.path}"), 'output', destination, add_options(tmp.path)
      output = %x{#{command}}
      unless File.readable?(destination) && File.size(destination) > 0
        raise PdftkError.new("failed to fill form with command\n#{command}\ncommand output was:\n#{output}")
      end
    ensure
      tmp.unlink if tmp
    end

    # pdftk.read '/path/to/form.pdf'
    # returns an instance of Nguyen::Pdf representing the given template
    def read(path)
      Pdf.new path, self
    end

    def get_field_names(template)
      read(template).fields
    end

    def call_pdftk(*args)
      %x{#{pdftk_command args}}
    end

    def cat(*files,output)
      files = files[0] if files[0].class == Array
      input = files.map{|f| %Q(#{f})}
      call_pdftk(*input,'output',output)
    end

    protected

      def pdftk_command(*args)
        "#{pdftk} #{args.flatten.compact.join ' '} 2>&1"
      end

      def add_options(pwd)
        return if options.empty?
        opt_args = []
        if options[:flatten]
          opt_args << 'flatten'
        end
        if options[:encrypt]
          opt_args.concat ['encrypt_128bit', 'owner_pw', pwd, options[:encrypt_options]]
        end
        opt_args
      end

  end
end
