import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_INDEXER_URL ? 
    `${process.env.NEXT_PUBLIC_INDEXER_URL}/graphql` : 
    'http://localhost:42069/graphql',
});

const authLink = setContext((_, { headers }) => {
  return {
    headers: {
      ...headers,
      'content-type': 'application/json',
    }
  }
});

const client = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          vaultMetrics: {
            merge(existing, incoming) {
              return incoming;
            },
          },
          deposits: {
            merge(existing, incoming) {
              return incoming;
            },
          },
          withdrawals: {
            merge(existing, incoming) {
              return incoming;
            },
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
    },
  },
});

export default client;