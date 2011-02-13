require "uglifier/node"

class Uglifier
  # Raised when compilation fails
  class Error < StandardError; end

  DEFAULTS = {
    :mangle => true, # Mangle variables names
    :toplevel => false, # Mangle top-level variable names
    :squeeze => true, # Squeeze code resulting in smaller, but less-readable code
    :seqs => true, # Reduce consecutive statements in blocks into single statement
    :dead_code => true, # Remove dead code (e.g. after return)
    :unsafe => false, # Optimizations known to be unsafe in some situations
    :copyright => false, # Show copyright message
    :beautify => false, # Ouput indented code
    :beautify_options => {
      :indent_level => 4,
      :indent_start => 0,
      :quote_keys => false,
      :space_colon => 0
    }
  }

  # Create new instance of Uglifier with given options
  def initialize(options = {})
    @options = DEFAULTS.merge(options)
    @node = Node.new
    export(@node.require("parse-js"), ["tokenizer", "parse"])
    process = @node.require("./process")
    process["set_logger"].call(lambda { |m| $stderr.puts m })

    export(process, ["ast_mangle", "ast_squeeze", "gen_code", "ast_walker"])
    export(@node.require("squeeze-more"), ["ast_squeeze_more"])
  end

  def compile(source)
    str = stringify(source)

    if @options[:copyright]
      copyright(str)
    else
      ""
    end << generate_code(ast(str))
  rescue Rhino::JavascriptError => e
    raise Error.new(e.message)
  end

  def self.compile(source, options = {})
    self.new(options).compile(source)
  end

  private

  def export(object, properties)
    properties.each do |property|
      @node[property] = object[property]
    end
  end

  def stringify(source)
    if source.respond_to? :read
      source.read
    else
      source.to_s
    end
  end

  def copyright(source)
    tokens = @node["tokenizer"].call(source, false)
    tokens.call.comments_before.inject("") do |copyright, comment|
      copyright + if comment["type"] == "comment1"
        "//" + comment["value"] + "\n"
      else
        "/*" + comment["value"] + "*/\n"
      end
    end
  end

  def generate_code(ast)
    @node["gen_code"].call(ast, @options[:beautify] && @options[:beautify_options])
  end

  def ast(source)
    squeeze_unsafe(squeeze(mangle(@node["parse"].call(source))))
  end

  def mangle(ast)
    return ast unless @options[:mangle]
    @node["ast_mangle"].call(ast, @options[:toplevel])
  end

  def squeeze(ast)
    return ast unless @options[:squeeze]

    @node["ast_squeeze"].call(ast, {
      "make_seqs" => @options[:seqs],
      "dead_code" => @options[:dead_code],
      "keep_comps" => !@options[:unsafe]
    })
  end

  def squeeze_unsafe(ast)
    return ast unless @options[:unsafe]
    @node["ast_squeeze_more"].call(ast)
  end
end
