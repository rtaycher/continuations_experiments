require 'continuation'

require 'pathname'
CSI = "\e["
def _code_to_chars(code)
    "#{CSI}#{code}m"
end

STYLE_BRIGHT = _code_to_chars(1)
FORE_BLUE = _code_to_chars(34)
STYLE_RESET_ALL = _code_to_chars(0)
S = FORE_BLUE
SR = STYLE_RESET_ALL
def debug_print_here(expr=nil)
    cl = caller_locations(1,1)[0]

    filename = Pathname.new(cl.absolute_path).basename
    puts "#{S}File: #{filename} Line: #{cl.lineno} Func: #{cl.label}#{SR}"
    result = eval expr if expr
    puts "#{S}Expr: #{expr} Type: #{result.class} Result: #{result}#{SR}" if expr    
end
def class_names(obj)
    class_obj = obj.class
    names = []
    name =''
    while class_obj and !(name == "StandardError")  do                
        name = class_obj.name
        names << name        
        class_obj = class_obj.superclass
 
   
    end
    names
end
$coroutine_exception_stack = []
class CoroutineExceptionHandling
    attr_reader :cc_to_begin, :rescue_continuations, :cc_to_ensure_block, :cc_to_go
    attr_accessor :ex
    def initialize
        @cc_to_begin = nil
        @rescue_continuations = {}
        @cc_to_ensure = nil
        @ensure_started = false
        @cc_to_go = nil
        @cc_ = nil
        @started_finally = false
        @started = false
        @ex=nil
        @ex_handled=false
    end
    def self.raise_(ex)
        debug_print_here "$coroutine_exception_stack"
        raise ex if $coroutine_exception_stack.empty?
        last_handle_context = $coroutine_exception_stack.last
        last_handle_context.ex = ex
        name = ex.class.name
        rescue_cc = last_handle_context.rescue_continuations.delete(name)
        if rescue_cc
            rescue_cc.call
        end
        if last_handle_context.cc_to_ensure_block
            last_handle_context.cc_to_ensure_block.call
        end
    end
    def begin_
        Kernel.callcc{|cc| @cc_to_begin=cc}        
        @started
    end
    def rescue_(ex_class=StandardError.new)
        if @started
            @cc_to_go.call
        end        
        class_names(ex_class).each do |name|
            Kernel.callcc{|cc| @rescue_continuations[name]=cc}
        end
        
        
        if @started
            @ex_handled = true
        end
        @started
    end
    def ensure_
        if @started
            @cc_to_go.call
        end
        Kernel.callcc{|cc| @cc_to_ensure=cc}
        if @started
           @ensure_started = true
        end
        @started
    end
    def go
        Kernel.callcc{|cc| @cc_to_go=cc}
        if @started
            if @cc_to_ensure and !@ensure_started                
                @cc_to_ensure.call
            end            
            $coroutine_exception_stack.pop
            if @ex && !@ex_handled
                CoroutineExceptionHandling.raise_ @ex
            end
        else
            @started = true
            $coroutine_exception_stack << self
            debug_print_here "$coroutine_exception_stack"
            debug_print_here
            @cc_to_begin.call            
        end
    end
end
CEH = CoroutineExceptionHandling

class CoroutineIterator
    include Enumerable
    attr_reader :skip
    def initialize        
        @cc_to_callee = nil
        @finished = false
        call_result = Kernel.callcc{|cc| @continuation_to_coroutine=cc}
        @skip = call_result != @continuation_to_coroutine
    end    
    def check
        raise "Couroutine not initialized" unless @cc_to_callee
        raise "Couroutine finished" if @finished
    end
    private :check
    def send(value)
        raise "Couroutine finished" if @finished     
        ret = Kernel.callcc{|cc| @cc_to_callee=cc}
        if ret == @cc_to_callee
            @continuation_to_coroutine.call value
        end
        ret
    end
    def next_
        raise "Couroutine finished" if @finished
        send(nil)
    end
    def yield_(value)
        check
        call_result = Kernel.callcc{|cc| @continuation_to_coroutine=cc}
        @skip = call_result != @continuation_to_coroutine  
        @cc_to_callee.call value unless skip
        call_result
    end
    def end_()        
        check
        @finished = true
        @cc_to_callee.call nil
    end
    def each         
        raise "Couroutine finished" if @finished

        value = self.next_()
        while !@finished                        
            puts "value: #{value}"
            yield value
            value = self.next_()
        end
    end
end

class A
    def a
        y=CoroutineIterator.new()
        return y unless y.skip
        restore = nil
        [1,2,3,4,5].each do |v|
            y.yield_(v)
        end
        y.yield_(10)
        y.end_()
    end
    #Scatch_return_exception(:a)
end


def test_exceptions2
    ctx = CEH.new
    if ctx.begin_
        puts "begin2"
        CEH.raise_ RangeError.new('ex2')
    end
    if ctx.rescue_ IOError
        puts "rescue2 IOError #{ctx.ex}"
    end
    if ctx.ensure_
        puts "ensure2"
    end 
    ctx.go    
end

def test_exceptions
    ctx = CEH.new
    if ctx.begin_
        puts "begin"
        #test_exceptions2
        CEH.raise_ TypeError.new('bob')
    end
    if ctx.rescue_
        puts "rescue plain #{ctx.ex}"
    end
    if ctx.rescue_ TypeError
        puts "rescue TypeError #{ctx.ex}"
    end
    if ctx.ensure_
        puts "ensure"
    end 
    ctx.go
end

A.new.a.each {|x| puts x}
puts A.new.a.map{|v| v*3}.select{|v| v%2 != 0}

#test_exceptions

#debug_print_here '$coroutine_exception_stack'