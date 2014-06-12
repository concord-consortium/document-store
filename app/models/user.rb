class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :documents, inverse_of: :owner, foreign_key: 'owner_id'

  validates :username, uniqueness: true, presence: true
end
