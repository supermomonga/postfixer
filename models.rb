# encoding: utf-8
require 'bundler'
Bundler.require

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.db")
DataMapper::Property::String.length 512


class Domain
  include DataMapper::Resource
  storage_names[:default] = 'domain'
  property :domain      , String   , key: true
  property :description , Text     , required: true
  property :aliases     , Integer  , required: true , default: 0
  property :mailboxes   , Integer  , required: true , default: 0
  property :maxquota    , Integer  , required: true , default: 0
  property :quota       , Integer  , required: true , default: 0
  property :transport   , String   , required: true , default: 'virtual'
  property :backupmx    , Integer  , required: true , default: 0
  property :updated     , DateTime , required: true
  property :modified    , DateTime , required: true
  property :active      , Integer  , required: true , default: 1
end

class Mailbox
  include DataMapper::Resource
  storage_names[:default] = 'mailbox'
  property :username   , String   , key: true
  property :password   , String   , required: true
  property :name       , String   , required: true
  property :maildir    , String   , required: true
  property :quota      , Integer  , required: true , default: 0
  property :local_part , String   , required: true
  property :domain     , String   , required: true
  property :updated    , DateTime , required: true
  property :modified   , DateTime , required: true
  property :active     , Integer  , required: true , default: 1
end

class Alias
  include DataMapper::Resource
  storage_names[:default] = 'alias'
  property :address  , String   , key: true
  property :goto     , String   , required: true
  property :domain   , String   , required: true
  property :updated  , DateTime , required: true
  property :modified , DateTime , required: true
  property :active   , Integer  , required: true , default: 1
end
