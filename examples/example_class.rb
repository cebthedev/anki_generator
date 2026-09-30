class Calculator
  attr_reader :history

  def initialize
    @history = []
  end

  def add(a, b)
    result = a + b
    @history << "#{a} + #{b} = #{result}"
    result
  end
end
