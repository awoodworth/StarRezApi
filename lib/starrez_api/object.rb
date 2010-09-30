# Much props to _why and his (poignant) guide
# This code can originally be found at
# http://viewsourcecode.org/why/hacking/seeingMetaclassesClearly.html

class Object
  # The hidden singleton lurks behind everyone
	def metaclass; class << self; self; end; end
	def meta_eval &blk; metaclass.instance_eval &blk; end

	# Adds methods to a metaclass
	def meta_def name, &blk
		meta_eval { define_method name, &blk }
	end

	# Defines an instance method within a class
	def class_def name, &blk
		class_eval { define_method name, &blk }
	end
end