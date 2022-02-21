const AWS = require("aws-sdk");
const NOTES_TABLE = process.env.NOTES_TABLE;

const documentClient = new AWS.DynamoDB.DocumentClient();

module.exports.handler = async (event, context) => {
  const id = event.body.id;
  await documentClient
    .delete({
      TableName: NOTES_TABLE,
      Key: {
        noteId: id,
      },
    })
    .promise();

  return {
    statusCode: 200,
    body: JSON.stringify({ message: "Item Deleted" }),
  };
};
