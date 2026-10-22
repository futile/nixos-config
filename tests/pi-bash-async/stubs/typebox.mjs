const schema = (type) => (options = {}) => ({ type, ...options });
export const Type = {
  Object: (properties, options = {}) => ({ type: "object", properties, ...options }),
  Optional: (inner) => ({ ...inner, optional: true }),
  String: schema("string"),
  Number: schema("number"),
  Integer: schema("integer"),
  Boolean: schema("boolean"),
};
