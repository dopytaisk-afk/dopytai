exports.handler = async function () {
  return {
    statusCode: 403,
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      error: "Odosielanie kontaktov bez zaplatenia je zakázané."
    })
  };
};
