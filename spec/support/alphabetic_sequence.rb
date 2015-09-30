module FactoryGirl
  class AlphabeticSequence < Sequence
    def initialize(name, *args, &proc)
      options  = args.extract_options!
      starting_value = args.shift || "000000000001"
      @ignore_overflow = options.fetch(:ignore_overflow) { false }
      super(name, starting_value, *args, &proc)
    end

    def increment_value
      previous = value
      super
      if warn_on_overflow? && value.length > previous.length
        raise "Your sequence has overflowed from #{previous} to #{value}. This can lead to random-seeming test failures if you are relying on ordering by this field."
      end
    end

    private

    def warn_on_overflow?
      !@ignore_overflow
    end
  end

  class DefinitionProxy
    def alphabetic_sequence(name, *args, &block)
      sequence = AlphabeticSequence.new(name, *args, &block)
      add_attribute(name) { increment_sequence(sequence) }
    end
  end
end
