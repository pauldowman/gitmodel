module GitModel

  # Generic GitModel exception class.
  class GitModelError < StandardError
  end

  # Raised when GitModel cannot find record by given id or set of ids.
  class RecordNotFound < GitModelError
  end

  # Raised by GitModel::Persistable.save! and GitModel::Persistable.create!
  # methods when record cannot be saved because record is invalid.
  class RecordNotSaved < GitModelError
  end

  class RecordExists < GitModelError
  end

  class RecordDoesntExist < GitModelError
  end

  class NullId < GitModelError
  end

  # Raised by GitModel::Persistable.find_all when query conditions are given
  # but there is no index generated
  class IndexRequired < GitModelError
  end

  class AttributeNotIndexed < GitModelError
  end

end
