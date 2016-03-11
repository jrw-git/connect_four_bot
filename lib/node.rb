class Node

  #include Comparable

  attr_reader :move, :subnode, :depth, :hash
  attr_accessor :value

  def initialize (move, value, depth, subnode, hash = nil)
    @move = move
    @value = value
    @depth = depth
    @subnode = subnode
    @hash = hash
  end

  # CRAZY FUCKING BUG IF I USED SPACESHIP OPERATOR TO COMPARE NODES DIRECTLY....
  # kept insisting that the "other" was a nil object.
  # switching to comparing values directly
  #def <=>(other)
  #  #puts "Other: #{other} OtherNull?#{other == nil}"
  #  if other == nil
  #    $stderr.puts "Error comparing values in node. This: #{self} Other: #{other} OtherNull?#{other == nil}"
  #    #other = Node.new(nil, 0, 0, 0)
  #  end
  #  @value.to_i <=> other.value.to_i
  #end

  def -@
    Node.new(@move.to_i, -@value.to_f, @depth.to_i, @subnode)
  end

  def to_s
    "(M#{@move}, V#{@value}, D#{@depth}, SN:#{@subnode})"
  end

end
