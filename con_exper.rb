require 'continuation' 

except_stack = []

class ReturnException < StandardError
  def initialize(value)
    @value = value
  end    
end

# ReturnException taken from http://stackoverflow.com/a/1893309/259130
module CatchReturnException
  def catch_return_exception(func_name)   # This is the function that will DO the decoration: given a function, it'll extend it to have 'documentation' functionality.
    new_name_for_old_function = "#{func_name}_old".to_sym   # We extend the old function by 'replacing' it - but to do that, we need to preserve the old one so we can still call it from the snazzy new function.
    alias_method(new_name_for_old_function, func_name)  # This function, alias_method(), does what it says on the tin - allows us to call either function name to do the same thing.  So now we have TWO references to the OLD crappy function.  Note that alias_method is NOT a built-in function, but is a method of Class - that's one reason we're doing this from a module.
    define_method(func_name) do |*args|   # Here we're writing a new method with the name func_name.  Yes, that means we're REPLACING the old method.
      puts "about to call #{func_name}(#{args.join(', ')})"  # ... do whatever extended functionality you want here ...
      begin
          return send(new_name_for_old_function, *args)  # This is the same as `self.send`.  `self` here is an instance of your extended class.  As we had TWO references to the original method, we still have one left over, so we can call it here.
      rescue  ReturnException => error
           return error.value
      end
    end
  end
end

coroutine_exception_stack = []
class CoroutineExceptionHandling
    def begin(&block)
        @block = block
    end
    def self.raise_
    end
    def rescue_
        call_result = Kernel.callcc{|cc| @continuation_to_coroutine=cc}
        @skip = call_result == @cc_to_coroutine        
    end
    def ensure_
        call_result = Kernel.callcc{|cc| @continuation_to_coroutine=cc}
        @skip = call_result == @cc_to_coroutine
    end

    def go
        coroutine_exception_stack << self
        @block.call
        
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

A.new.a.each {|x| puts x}

#puts A.new.a.map{|v| v*3}.select{|v| v%2 != 0}

def test_exceptions
    CEH.new.begin {|| 
        puts "yo"
    }.rescue_ {||
        []
    }.ensure_ {|| 
    }.go
end
#test_exceptions