# Convertible provides methods for converting a pagelike item
# from a certain type of markup into actual content
#
# Requires
#   self.site -> Jekyll::Site
module Jekyll
  module Convertible
    # Return the contents as a string
    def to_s
      self.content || ''
    end

    # Read the YAML frontmatter
    #   +base+ is the String path to the dir containing the file
    #   +name+ is the String filename of the file
    #
    # Returns nothing
    def read_yaml(base, name)
      self.content = File.read(File.join(base, name))
      
      if self.content =~ /^(---\s*\n.*?)\n---\s*\n/m
        self.content = self.content[($1.size + 5)..-1]
        
        # will barf if textile or markdown lead to malformed strings in yaml
        
        # split into lines
        content_lines = $1.split("\n")
        
        # for each line in place
        content_lines.collect! do |line|
          
          # split on YAML mapping indicator
          line_array = line.split(": ")
          
          # rollup rest of line (in case accidentally included another mapping)
          # inspect to escape quotes
          line_array[1] = line_array[1..-1].join.inspect
          
          # join back around mapping
          line_array.join(": ")
        end
                
        # join up rest of lines and load into YAML
        self.data = YAML.load(content_lines.join("\n"))
      end
    end

    # Transform the contents based on the file extension.
    #
    # Returns nothing
    def transform
      case self.content_type
      when 'textile'
        self.ext = ".html"
        self.content = self.site.textile(self.content)
      when 'markdown'
        self.ext = ".html"
        self.content = self.site.markdown(self.content)
      end
    end

    # Determine which formatting engine to use based on this convertible's
    # extension
    #
    # Returns one of :textile, :markdown or :unknown
    def content_type
      case self.ext[1..-1]
      when /textile/i
        return 'textile'
      when /markdown/i, /mkdn/i, /md/i
        return 'markdown'
      end
      return 'unknown'
    end

    # Add any necessary layouts to this convertible document
    #   +layouts+ is a Hash of {"name" => "layout"}
    #   +site_payload+ is the site payload hash
    #
    # Returns nothing
    def do_layout(payload, layouts)
      info = { :filters => [Jekyll::Filters], :registers => { :site => self.site } }

      # render and transform content (this becomes the final content of the object)
      payload["content_type"] = self.content_type
      self.content = Liquid::Template.parse(self.content).render(payload, info)
      self.transform

      # output keeps track of what will finally be written
      self.output = self.content

      # recursively render layouts
      layout = layouts[self.data["layout"]]
      while layout
        payload = payload.deep_merge({"content" => self.output, "page" => layout.data})
        self.output = Liquid::Template.parse(layout.content).render(payload, info)

        layout = layouts[layout.data["layout"]]
      end
    end
  end
end
