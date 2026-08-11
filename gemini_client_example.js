/**
 * Gladstone Webhost Gemini API Client Example
 * ----------------------------------------------------
 * You can include or adapt this JavaScript function in your local website frontend.
 * It sends a POST request to your Webhost backend server at http://192.168.50.217:5050/api/query
 */

async function sendGeminiPrompt(userPrompt, modelName = 'gemini-2.5-flash') {
    const SERVER_URL = 'http://192.168.50.217:5050/api/query';

    try {
        console.log(`Sending prompt to Webhost Gemini API: "${userPrompt}"`);
        const response = await fetch(SERVER_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                prompt: userPrompt,
                model: modelName
            })
        });

        const data = await response.json();

        if (response.ok && data.status === 'success') {
            console.log('Gemini Result:', data.result);
            return data.result;
        } else {
            console.error('Gemini API Error:', data.message || data);
            throw new Error(data.message || 'Error querying Gemini API');
        }
    } catch (error) {
        console.error('Failed to communicate with Webhost Gemini Backend:', error);
        throw error;
    }
}

// Example usage:
// sendGeminiPrompt('Summarize the top 3 benefits of solar energy')
//     .then(result => console.log('Response:', result))
//     .catch(err => console.error(err));
