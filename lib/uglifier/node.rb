require "rhino"

class Uglifier
  class Node < Rhino::Context
    def initialize(*args, &blk)
      @exports = {}
      super(*args, &blk)
      self.load(File.join(
        File.dirname(__FILE__), "..", "..", "vendor", "reduce.js"
      ))
      self["require"] = lambda { |r|
        self.require(File.basename(r, ".js"))
      }
    end
    def require(file)
      @exports[file] ||= begin
        @exports[file] = self.eval("new Object();") # Prevent circular dependencies

        eval(
          export(
            File.read(
              File.join(
                File.dirname(__FILE__), "..", "..", "vendor", "uglifyjs", "lib", File.basename(file, ".js") + ".js"
              )
            )
          )
        ).each do |key, value|
          @exports[file][key] = value
        end
        @exports[file]
      end
    end

    private

    def export(source)
      "(function() { var exports = {};\n #{source}\n return exports; }())"
    end
  end
end
