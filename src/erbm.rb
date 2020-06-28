require 'erb'

class ERBMethod
  def initialize(mod, method_name, fname, dir=nil)
    @fname = build_fname(fname, dir)
    @method_name = method_name
    @mod = mod
    reload
  end

  def reload
    mtime = File.mtime(@fname)
    return if @mtime && @mtime == mtime
    @mtime = mtime
    erb = File.open(@fname) {|f| ERB.new(f.read)}
    erb.def_method(@mod, @method_name, @fname)
  end
  
  private
  def build_fname(fname, dir)
    case dir
    when String
      ary = [dir]
    when Array
      ary = dir
    else
      ary = $:
    end

    found = fname # default
    ary.each do |dir|
      path = File::join(dir, fname)
      if File::readable?(path)
        found = path
        break
      end
    end
    found
  end
end

if __FILE__ == $0
  it = ERBMethod.new(self.class, 'to_html', 'index.html')
  puts to_html
end