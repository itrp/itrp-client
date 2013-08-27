class Object
  # Encapsulates the common pattern of:
  #
  #   alias_method :foo_without_feature, :foo
  #   alias_method :foo, :foo_with_feature
  #
  # With this, you simply do:
  #
  #   alias_method_chain :foo, :feature
  #
  # And both aliases are set up for you.
  #
  # Query and bang methods (foo?, foo!) keep the same punctuation:
  #
  #   alias_method_chain :foo?, :feature
  #
  # is equivalent to
  #
  #   alias_method :foo_without_feature?, :foo?
  #   alias_method :foo?, :foo_with_feature?
  #
  # so you can safely chain foo, foo?, and foo! with the same feature.
  def alias_method_chain(target, feature)
    # Strip out punctuation on predicates or bang methods since
    # e.g. target?_without_feature is not a valid method name.
    aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
    yield(aliased_target, punctuation) if block_given?

    with_method, without_method = "#{aliased_target}_with_#{feature}#{punctuation}", "#{aliased_target}_without_#{feature}#{punctuation}"

    alias_method without_method, target
    alias_method target, with_method

    case
      when public_method_defined?(without_method)
        public target
      when protected_method_defined?(without_method)
        protected target
      when private_method_defined?(without_method)
        private target
    end
  end unless method_defined?(:alias_method_chain)

  unless method_defined?(:try)
    # Invokes the method identified by the symbol +method+, passing it any arguments
    # and/or the block specified, just like the regular Ruby <tt>Object#send</tt> does.
    #
    # *Unlike* that method however, a +NoMethodError+ exception will *not* be raised
    # and +nil+ will be returned instead, if the receiving object is a +nil+ object or NilClass.
    #
    # ==== Examples
    #
    # Without try
    #   @person && @person.name
    # or
    #   @person ? @person.name : nil
    #
    # With try
    #   @person.try(:name)
    #
    # +try+ also accepts arguments and/or a block, for the method it is trying
    #   Person.try(:find, 1)
    #   @people.try(:collect) {|p| p.name}
    #--
    # This method definition below is for rdoc purposes only. The alias_method call
    # below overrides it as an optimization since +try+ behaves like +Object#send+,
    # unless called on +NilClass+.
    def try(method, *args, &block)
      send(method, *args, &block)
    end
    remove_method :try
    alias_method :try, :__send__
  end

end

class NilClass #:nodoc:
  def try(*args)
    nil
  end
end

# blank? method

class Object
  # An object is blank if it's false, empty, or a whitespace string.
  # For example, "", "   ", +nil+, [], and {} are blank.
  #
  # This simplifies:
  #
  #   if !address.nil? && !address.empty?
  #
  # ...to:
  #
  #   if !address.blank?
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end unless method_defined?(:blank?)

end

class NilClass #:nodoc:
  def blank?
    true
  end
end

class FalseClass #:nodoc:
  def blank?
    true
  end
end

class TrueClass #:nodoc:
  def blank?
    false
  end
end

class Array #:nodoc:
  alias_method :blank?, :empty? unless method_defined?(:blank?)
end

class Hash #:nodoc:
  alias_method :blank?, :empty? unless method_defined?(:blank?)
end

class String #:nodoc:
  def blank?
    self !~ /\S/
  end
end

class Numeric #:nodoc:
  def blank?
    false
  end
end