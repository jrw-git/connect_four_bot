class Node

  include Comparable

  attr_reader :column, :value, :subnode

  def initialize (column, value, subnode)
    @value = value
    @column = column
    @subnode = subnode
  end

  def <=>(other)
    @value <=> other.value
  end

  def -@
    Node.new(@column, -@value, @subnode)
  end

  def to_s
    "(C:#{@column} V:#{@value}, SN:#{@subnode} )"
  end

end
