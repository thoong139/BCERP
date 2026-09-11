// QD4 pos-02 — N+1 query fixture
// Probe: P-QD4-bundle-size-audit (Part 2: N+1 detection)
// Expected signal: n_plus_1 HIGH (await DB call inside for loop)

interface User {
  id: string;
  name: string;
  email: string;
}

interface Post {
  id: string;
  userId: string;
  title: string;
  content: string;
}

// Simulated repository (no real DB connection needed for static analysis)
const repo = {
  async findOne(query: object): Promise<User | null> {
    return null;
  },
  async findById(id: string): Promise<User | null> {
    return null;
  },
};

const postRepo = {
  async findAll(userId: string): Promise<Post[]> {
    return [];
  },
};

// BAD: N+1 query — await DB call inside for loop (triggers P1 N+1 detection)
export async function getUsersWithPosts(userIds: string[]): Promise<Array<{ user: User | null; posts: Post[] }>> {
  const results = [];
  for (const id of userIds) {
    const user = await repo.findOne({ where: { id } });  // await .findOne( inside for loop
    const posts = await postRepo.findAll(id);
    results.push({ user, posts });
  }
  return results;
}

// BAD: Another N+1 pattern — findById inside loop
export async function hydrateUsers(ids: string[]): Promise<(User | null)[]> {
  const hydrated = [];
  for (const id of ids) {
    const user = await repo.findById(id);  // await .findById( inside for loop
    hydrated.push(user);
  }
  return hydrated;
}
