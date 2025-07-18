#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";

// Environment variables
const SLAB_API_TOKEN = process.env.SLAB_API_TOKEN;
const SLAB_API_URL =
  process.env.SLAB_API_URL || "https://api.slab.com/v1/graphql";

if (!SLAB_API_TOKEN) {
  console.error("SLAB_API_TOKEN environment variable is required");
  process.exit(1);
}

class SlabServer {
  constructor() {
    this.server = new Server(
      {
        name: "slab-mcp-server",
        version: "0.1.0",
      },
      {
        capabilities: {
          tools: {},
        },
      },
    );

    this.setupToolHandlers();

    // Error handling
    this.server.onerror = (error) => console.error("[MCP Error]", error);
    process.on("SIGINT", async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "slab_search",
          description: "Search through Slab documentation and posts",
          inputSchema: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "Search query string",
              },
              limit: {
                type: "number",
                description:
                  "Maximum number of results to return (default: 10)",
                default: 10,
              },
            },
            required: ["query"],
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case "slab_search":
            return await this.searchPosts(args.query, args.limit || 10);
          default:
            throw new McpError(
              ErrorCode.MethodNotFound,
              `Unknown tool: ${name}`,
            );
        }
      } catch (error) {
        if (error instanceof McpError) {
          throw error;
        }
        throw new McpError(
          ErrorCode.InternalError,
          `Error executing ${name}: ${error.message}`,
        );
      }
    });
  }

  async makeGraphQLRequest(query, variables = {}) {
    const response = await fetch(SLAB_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: SLAB_API_TOKEN,
      },
      body: JSON.stringify({
        query,
        variables,
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();

    if (data.errors) {
      throw new Error(`GraphQL errors: ${JSON.stringify(data.errors)}`);
    }

    return data.data;
  }

  async searchPosts(searchTerm, limit = 10) {
    const searchQuery = `
    query SearchPosts($query: String!, $first: Int) {
      search(query: $query, first: $first) {
        edges {
          node {
            ... on PostSearchResult {
              title
              content
              highlight
              post {
                id
                title
                content
                insertedAt
                updatedAt
                publishedAt
                owner {
                  id
                  name
                  email
                }
                topics {
                  id
                  name
                }
              }
            }
            ... on UserSearchResult {
              name
              title
              description
              user {
                id
                name
                email
              }
            }
            ... on CommentSearchResult {
              content
              comment {
                id
                content
                insertedAt
                author {
                  id
                  name
                  email
                }
              }
            }
          }
        }
        pageInfo {
          hasNextPage
          hasPreviousPage
          startCursor
          endCursor
        }
      }
    }
  `;

    const response = await this.makeGraphQLRequest(searchQuery, {
      query: searchTerm,
      first: limit,
    });

    // Check if there are GraphQL errors
    if (response.errors) {
      console.log("GraphQL errors:", response.errors);
      return {
        content: [
          {
            type: "text",
            text:
              "Search failed with errors: " + JSON.stringify(response.errors),
          },
        ],
      };
    }

    // Check if search results exist - note: no "data" wrapper in Slab's response
    if (!response.search || !response.search.edges) {
      console.log("No search results found");
      return {
        content: [
          {
            type: "text",
            text: 'No results found for "' + searchTerm + '"',
          },
        ],
      };
    }

    const edges = response.search.edges;

    return {
      content: [
        {
          type: "text",
          text:
            `Found ${edges.length} results matching "${searchTerm}":\n\n` +
            edges
              .map((edge) => {
                const node = edge.node;

                // Handle PostSearchResult
                if (node.post) {
                  const post = node.post;
                  // Parse the JSON content to get readable text
                  const contentText = extractTextFromQuillContent(post.content);
                  const preview = contentText
                    ? contentText.substring(0, 200) + "..."
                    : "No content available";

                  return (
                    `**${post.title}**\n` +
                    `Type: Post\n` +
                    `ID: ${post.id}\n` +
                    `Owner: ${post.owner ? post.owner.name : "Unknown"}\n` +
                    `Topics: ${post.topics && post.topics.length > 0 ? post.topics.map((t) => t.name).join(", ") : "None"}\n` +
                    `Published: ${post.publishedAt ? new Date(post.publishedAt).toLocaleDateString() : "Not published"}\n` +
                    `Updated: ${post.updatedAt ? new Date(post.updatedAt).toLocaleDateString() : "Unknown"}\n` +
                    `Preview: ${preview}\n`
                  );
                }

                // Handle CommentSearchResult
                else if (node.comment) {
                  const comment = node.comment;
                  // Parse the JSON content to get readable text
                  const contentText = extractTextFromQuillContent(
                    comment.content,
                  );
                  const preview = contentText
                    ? contentText.substring(0, 200) + "..."
                    : "No content available";

                  return (
                    `**Comment** by ${comment.author ? comment.author.name : "Unknown"}\n` +
                    `Type: Comment\n` +
                    `ID: ${comment.id}\n` +
                    `Author: ${comment.author ? comment.author.name + " (" + comment.author.email + ")" : "Unknown"}\n` +
                    `Created: ${comment.insertedAt ? new Date(comment.insertedAt).toLocaleDateString() : "Unknown"}\n` +
                    `Content: ${preview}\n`
                  );
                }

                // Handle UserSearchResult
                else if (node.user) {
                  const user = node.user;
                  return (
                    `**${user.name}**\n` +
                    `Type: User\n` +
                    `ID: ${user.id}\n` +
                    `Email: ${user.email || "Not available"}\n` +
                    `Title: ${node.title || "No title"}\n` +
                    `Description: ${node.description || "No description"}\n`
                  );
                }

                // Handle other types
                else {
                  return (
                    `**Unknown Result Type**\n` +
                    `Content: ${JSON.stringify(node, null, 2)}\n`
                  );
                }
              })
              .join("\n---\n"),
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Slab MCP server running on stdio");
  }
}

// Helper function to extract readable text from Quill's JSON format
function extractTextFromQuillContent(content) {
  if (!content) return "";

  try {
    // Content is already parsed JSON (array of Quill delta operations)
    const deltaOps =
      typeof content === "string" ? JSON.parse(content) : content;

    return deltaOps
      .filter((op) => op.insert && typeof op.insert === "string")
      .map((op) => op.insert)
      .join("")
      .trim();
  } catch (e) {
    console.error("Error parsing Quill content:", e);
    return content.toString();
  }
}

const server = new SlabServer();
server.run().catch(console.error);
