Table BaseTimestampedModel {
  id bigint [primary key]
  created datetime
  modified datetime
}


Table Category {
  id bigint [primary key]
  title varchar
  purpose varchar
  help_text varchar
}


Table Program {
  id bigint [primary key]
  name varchar
  duration time
  description varchar
  category_id bigint [ref: > Category.id]
}


Table IotDevice {
  id uuid [primary key]
  hostname varchar(63)
  category_id bigint [ref: > Category.id]
}


Table ActiveProgram {
  id bigint [primary key]
  start_time time
  program_id bigint [ref: > Program.id]
  device_id uuid [ref: > IotDevice.id]
  timestamp_id bigint [ref: > BaseTimestampedModel.id]
}
