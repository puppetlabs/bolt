# frozen_string_literal: true

Facter.add(:myfact) do
  setcode {
    'there'
  }
end
